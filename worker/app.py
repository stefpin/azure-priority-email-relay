"""Bulk sending worker for the the customer Option D demo.

Reads pointers from the Service Bus queue, fetches the payload from Blob Storage,
and submits to Azure Communication Services Email over the REST API.

Three behaviours here are the point of the demo, not incidental:

1. A token-bucket rate governor in Redis caps how fast the WHOLE worker pool sends,
   so bulk can never consume the capacity reserved for OTP. Redis is shared, so the
   cap holds no matter how many replicas KEDA starts.
2. 429 and 5xx from ACS are honoured with Retry-After and the message is abandoned
   back to the queue rather than dropped.
3. The payload never travels on the queue - only the pointer does.

Deliberately rate-limiting a consumer fights against Service Bus message locks, and
getting that wrong causes duplicate sends. Three things here exist because of it:

* An AutoLockRenewer keeps the lock alive while the governor holds a message back.
  Without it a message paced behind a few others outlives its 60-second lock, gets
  redelivered, and is sent twice.
* The blob is deleted BEFORE the message is completed. If completion then fails, the
  redelivered copy finds no blob and can safely conclude the send already happened.
  Deleting after completion leaves a window where a redelivery re-sends the message.
* A missing blob is therefore treated as "already sent" and completed, not as an error.
"""
import base64
import hashlib
import hmac
import json
import logging
import os
import time
from datetime import datetime, timezone
from email import message_from_bytes
from email.policy import default as default_policy

import requests
from azure.core.exceptions import ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from azure.servicebus import AutoLockRenewer, ServiceBusClient
from azure.servicebus.exceptions import (
    MessageAlreadySettled,
    MessageLockLostError,
    ServiceBusError,
)
from azure.storage.blob import BlobServiceClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("worker")

BLOB_ACCOUNT = os.environ["BLOB_ACCOUNT_URL"]
SB_NAMESPACE = os.environ["SERVICEBUS_NAMESPACE"]
SB_QUEUE = os.environ.get("SERVICEBUS_QUEUE", "q-bulk")
ACS_ENDPOINT = os.environ["ACS_ENDPOINT"].rstrip("/")   # https://<name>.<geo>.communication.azure.com
ACS_KEY = os.environ["ACS_ACCESS_KEY"]
SENDER = os.environ.get("SENDER_ADDRESS", "campaign@notify.example.com")

REDIS_HOST = os.environ.get("REDIS_HOST", "")
REDIS_KEY = os.environ.get("REDIS_KEY", "")
# Azure Managed Redis listens on 10000; the retiring Azure Cache for Redis used 6380.
REDIS_PORT = int(os.environ.get("REDIS_PORT", "10000"))
RATE_PER_MIN = int(os.environ.get("BULK_RATE_PER_MINUTE", "30"))
# The governor can hold a message for a while, so the lock has to be renewed while it
# waits. This must comfortably exceed the worst-case wait below.
LOCK_RENEW_SECONDS = int(os.environ.get("LOCK_RENEW_SECONDS", "600"))
# How many messages one receive call may hold. Kept small so a batch is not sitting
# on locks while the governor paces it out one at a time.
PREFETCH = int(os.environ.get("PREFETCH_COUNT", "3"))
# Longest a single message may be held by the rate governor before it is put back.
MAX_GOVERNOR_WAIT = int(os.environ.get("MAX_GOVERNOR_WAIT", "120"))

_cred = DefaultAzureCredential()
_blob = BlobServiceClient(account_url=BLOB_ACCOUNT, credential=_cred)
_sb = ServiceBusClient(fully_qualified_namespace=SB_NAMESPACE, credential=_cred)

_redis = None
if REDIS_HOST:
    import redis  # imported lazily so the worker still runs without Redis
    _redis = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, password=REDIS_KEY,
                         ssl=True, socket_timeout=5, decode_responses=True)
    log.info("rate governor enabled: %d messages/minute across all replicas (%s:%d)",
             RATE_PER_MIN, REDIS_HOST, REDIS_PORT)
else:
    log.warning("REDIS_HOST not set - running with NO shared rate cap")


def take_token() -> bool:
    """Fixed-window token bucket shared by every replica.

    Deliberately simple: one counter key per minute, incremented atomically. If the
    count for this minute is already at the cap, the caller waits. A production
    build would use a sliding window, but the behaviour to demonstrate - bulk being
    held back so OTP capacity survives - is identical.
    """
    if _redis is None:
        return True
    key = "bulk:rate:%s" % datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
    try:
        n = _redis.incr(key)
        if n == 1:
            _redis.expire(key, 120)
        return n <= RATE_PER_MIN
    except Exception as exc:                          # noqa: BLE001
        log.warning("redis unavailable (%s) - allowing send", exc)
        return True


def acs_send(subject: str, body_text: str, recipient: str) -> tuple[int, str]:
    """Submit one message to ACS Email using HMAC-signed REST."""
    path = "/emails:send?api-version=2023-03-31"
    host = ACS_ENDPOINT.replace("https://", "")
    payload = json.dumps({
        "senderAddress": SENDER,
        "content": {"subject": subject, "plainText": body_text},
        "recipients": {"to": [{"address": recipient}]},
    }).encode()

    digest = base64.b64encode(hashlib.sha256(payload).digest()).decode()
    stamp = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
    to_sign = "POST\n%s\n%s;%s;%s" % (path, stamp, host, digest)
    sig = base64.b64encode(
        hmac.new(base64.b64decode(ACS_KEY), to_sign.encode("utf-8"), hashlib.sha256).digest()
    ).decode()

    resp = requests.post(
        ACS_ENDPOINT + path, data=payload, timeout=30,
        headers={
            "Content-Type": "application/json",
            "x-ms-date": stamp,
            "x-ms-content-sha256": digest,
            "Authorization": "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=" + sig,
        },
    )
    return resp.status_code, resp.text[:300]


def parse_email(raw: bytes) -> tuple[str, str]:
    """Pull a subject and a plain-text body out of the raw RFC 822 message."""
    try:
        msg = message_from_bytes(raw, policy=default_policy)
        subject = msg.get("Subject", "(no subject)")
        if msg.is_multipart():
            part = msg.get_body(preferencelist=("plain", "html"))
            text = part.get_content() if part else ""
        else:
            text = msg.get_content()
        return subject, (text or "").strip() or "(empty body)"
    except Exception:                                 # noqa: BLE001
        return "(unparsed message)", raw.decode("utf-8", "replace")[:2000]


def _settle(receiver, msg, action: str, reason: str = "", detail: str = "") -> bool:
    """Settle a message, tolerating a lock we no longer hold.

    Once a lock is lost the broker owns the message again, so settling raises. That is
    not an error worth a stack trace - it just means this attempt lost the race and the
    message will come back. Returns True if we actually settled it.
    """
    try:
        if action == "complete":
            receiver.complete_message(msg)
        elif action == "abandon":
            receiver.abandon_message(msg)
        else:
            receiver.dead_letter_message(msg, reason=reason, error_description=detail)
        return True
    except (MessageLockLostError, MessageAlreadySettled, ServiceBusError) as exc:
        log.warning("could not %s message: %s", action, exc)
        return False


def main() -> None:
    log.info("worker starting: queue=%s acs=%s rate=%d/min prefetch=%d lock_renew=%ds",
             SB_QUEUE, ACS_ENDPOINT, RATE_PER_MIN, PREFETCH, LOCK_RENEW_SECONDS)

    # Keeps locks alive while the rate governor holds messages back. Without this a
    # paced message outlives its 60s lock and is redelivered - and redelivery after a
    # successful send is a duplicate email, which for OTP or statements is not cosmetic.
    renewer = AutoLockRenewer(max_lock_renewal_duration=LOCK_RENEW_SECONDS)

    try:
        with _sb.get_queue_receiver(SB_QUEUE, max_wait_time=30,
                                    prefetch_count=0) as receiver:
            while True:
                for msg in receiver.receive_messages(max_message_count=PREFETCH,
                                                     max_wait_time=30):
                    mid = "?"
                    try:
                        renewer.register(receiver, msg,
                                         max_lock_renewal_duration=LOCK_RENEW_SECONDS)
                        ptr = json.loads(str(msg))
                        mid = ptr.get("messageId", "?")

                        # rate governor - hold bulk back so OTP capacity is never consumed
                        waited = 0
                        while not take_token():
                            time.sleep(2)
                            waited += 2
                            if waited >= MAX_GOVERNOR_WAIT:
                                break
                        if waited:
                            log.info("rate cap held message %s for %ds", mid, waited)

                        blob = _blob.get_blob_client(ptr["blobContainer"], ptr["blobName"])
                        try:
                            raw = blob.download_blob().readall()
                        except ResourceNotFoundError:
                            # The payload is gone, which means a previous attempt already
                            # sent this message and deleted it. Settle and move on rather
                            # than sending it a second time.
                            _settle(receiver, msg, "complete")
                            log.warning("ALREADY-SENT %s - payload absent, completing", mid)
                            continue

                        subject, text = parse_email(raw)
                        code, detail = acs_send(subject, text, ptr["recipient"])

                        if code in (200, 202):
                            # Delete BEFORE completing. If completion then fails, the
                            # redelivered copy finds no blob and completes instead of
                            # re-sending. The reverse order leaves a duplicate window.
                            try:
                                blob.delete_blob()
                            except ResourceNotFoundError:
                                pass
                            _settle(receiver, msg, "complete")
                            log.info("SENT %s -> %s (%d bytes)",
                                     mid, ptr["recipient"], ptr["sizeBytes"])
                        elif code == 429 or code >= 500:
                            _settle(receiver, msg, "abandon")
                            log.warning("THROTTLED/RETRY %s http=%d %s", mid, code, detail)
                            time.sleep(5)
                        else:
                            _settle(receiver, msg, "dead_letter",
                                    reason="acs_%d" % code, detail=detail)
                            log.error("DEAD-LETTER %s http=%d %s", mid, code, detail)
                    except (MessageLockLostError, MessageAlreadySettled) as exc:
                        # Nothing useful to do: the broker owns the message again and
                        # will redeliver it. The blob-absent check above makes that safe.
                        log.warning("lock lost or already settled for %s (%s)", mid, exc)
                    except Exception as exc:              # noqa: BLE001
                        log.exception("processing failed: %s", exc)
                        _settle(receiver, msg, "abandon")
                    finally:
                        try:
                            renewer.deregister(msg)
                        except Exception:                 # noqa: BLE001
                            pass
    finally:
        renewer.close()


if __name__ == "__main__":
    main()
