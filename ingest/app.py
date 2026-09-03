"""Claim-check writer for the the customer Option D demo.

Postfix hands every BULK message to this service over HTTP. The service writes the
full message body to Blob Storage (the "payload") and puts only a small pointer on
the Service Bus queue. That is the claim-check pattern, and at the customer's real average
message size of several hundred KB it is mandatory rather than optional: the payload exceeds
the Service Bus Standard limit of 256 KB.

OTP never reaches this service. It goes straight from Postfix to ACS.
"""
import json
import logging
import os
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.storage.blob import BlobServiceClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ingest")

BLOB_ACCOUNT = os.environ["BLOB_ACCOUNT_URL"]          # https://<name>.blob.core.windows.net
BLOB_CONTAINER = os.environ.get("BLOB_CONTAINER", "payloads")
SB_NAMESPACE = os.environ["SERVICEBUS_NAMESPACE"]      # <name>.servicebus.windows.net
SB_QUEUE = os.environ.get("SERVICEBUS_QUEUE", "q-bulk")

_cred = DefaultAzureCredential()
_blob = BlobServiceClient(account_url=BLOB_ACCOUNT, credential=_cred)
_sb = ServiceBusClient(fully_qualified_namespace=SB_NAMESPACE, credential=_cred)


def _ensure_container() -> None:
    try:
        _blob.create_container(BLOB_CONTAINER)
        log.info("created container %s", BLOB_CONTAINER)
    except Exception:
        pass  # already exists


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _reply(self, code: int, body: dict) -> None:
        raw = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        # Container Apps health probe
        if self.path in ("/health", "/"):
            self._reply(200, {"status": "ok", "service": "claim-check-writer"})
        else:
            self._reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/submit":
            self._reply(404, {"error": "not found"})
            return
        try:
            n = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(n)

            sender = self.headers.get("X-Sender", "unknown")
            recipient = self.headers.get("X-Recipient", "unknown")
            msg_id = str(uuid.uuid4())

            # 1. payload to Blob - this is the part that would be several hundred KB at scale
            blob_name = "%s/%s.eml" % (datetime.now(timezone.utc).strftime("%Y/%m/%d"), msg_id)
            _blob.get_blob_client(BLOB_CONTAINER, blob_name).upload_blob(raw, overwrite=True)

            # 2. pointer to Service Bus - a few hundred bytes, never the body
            pointer = {
                "messageId": msg_id,
                "blobContainer": BLOB_CONTAINER,
                "blobName": blob_name,
                "sender": sender,
                "recipient": recipient,
                "sizeBytes": len(raw),
                "submittedUtc": datetime.now(timezone.utc).isoformat(),
            }
            with _sb.get_queue_sender(SB_QUEUE) as sender_client:
                sender_client.send_messages(
                    ServiceBusMessage(json.dumps(pointer), message_id=msg_id)
                )

            log.info("queued %s from=%s bytes=%d blob=%s", msg_id, sender, len(raw), blob_name)
            self._reply(202, {"accepted": True, "messageId": msg_id, "sizeBytes": len(raw)})
        except Exception as exc:                      # noqa: BLE001
            log.exception("submit failed")
            self._reply(500, {"error": str(exc)})

    def log_message(self, fmt, *args):
        pass  # quieten the default per-request stderr logging


if __name__ == "__main__":
    _ensure_container()
    port = int(os.environ.get("PORT", "8080"))
    log.info("claim-check writer listening on %d -> blob=%s queue=%s",
             port, BLOB_CONTAINER, SB_QUEUE)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
