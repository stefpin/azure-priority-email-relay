#!/usr/bin/env python3
"""Postfix pipe transport for the the customer Option D demo - the BULK lane only.

Postfix hands a bulk message to this script on stdin. The script POSTs it to the
claim-check writer Container App, which stores the payload in Blob and puts a
pointer on Service Bus.

Exit codes matter to Postfix and are chosen deliberately:
  0  = accepted, Postfix considers the message delivered to this transport
  75 = temporary failure (EX_TEMPFAIL), Postfix will retry - used for any error,
       because losing a customer's e-statement is worse than sending it late.

OTP never reaches this script. Postfix routes OTP straight to ACS on 587 using a
sender_dependent_relayhost_maps entry, so the fast path has no queue at all.
"""
import os
import sys
import urllib.error
import urllib.request

INGEST_URL = os.environ.get("INGEST_URL", "")
TIMEOUT = int(os.environ.get("INGEST_TIMEOUT", "30"))

EX_OK = 0
EX_TEMPFAIL = 75


def main() -> int:
    if not INGEST_URL:
        sys.stderr.write("claimcheck: INGEST_URL is not set\n")
        return EX_TEMPFAIL

    # Postfix passes sender and recipient as argv via master.cf
    sender = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    recipient = sys.argv[2] if len(sys.argv) > 2 else "unknown"
    raw = sys.stdin.buffer.read()

    req = urllib.request.Request(
        INGEST_URL.rstrip("/") + "/submit",
        data=raw,
        method="POST",
        headers={
            "Content-Type": "message/rfc822",
            "X-Sender": sender,
            "X-Recipient": recipient,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            if resp.status in (200, 202):
                sys.stderr.write("claimcheck: accepted %d bytes from %s\n" % (len(raw), sender))
                return EX_OK
            sys.stderr.write("claimcheck: unexpected status %d\n" % resp.status)
            return EX_TEMPFAIL
    except urllib.error.HTTPError as exc:
        sys.stderr.write("claimcheck: HTTP %d %s\n" % (exc.code, exc.read()[:200]))
        return EX_TEMPFAIL
    except Exception as exc:                          # noqa: BLE001
        sys.stderr.write("claimcheck: %s\n" % exc)
        return EX_TEMPFAIL


if __name__ == "__main__":
    sys.exit(main())
