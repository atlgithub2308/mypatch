#!/usr/bin/env python3

import imaplib
import email
import time
import sys
import json

# Hardcoded configuration
EMAIL = "angteckleong@gmail.com"
PASSWORD = "wdsjdzpvjhmgceej"  # App password for Gmail
IMAP_SERVER = "imap.gmail.com"
APPROVAL_SUBJECT = "Approval Request"  # Hardcoded subject
TIMEOUT = 86400  # Hardcoded timeout (24 hours)

# Connect to the email server
try:
    mail = imaplib.IMAP4_SSL(IMAP_SERVER)
    mail.login(EMAIL, PASSWORD)
    mail.select("inbox")
except Exception as e:
    print(json.dumps({"success": False, "message": f"Failed to connect to email server: {e}"}))
    sys.exit(1)

# Function to check for approval in the latest 10 emails
def check_approval(mail):
    status, messages = mail.search(None, 'ALL')
    if status != "OK":
        return False, "Failed to search emails."

    message_ids = messages[0].split()
    latest_message_ids = message_ids[-10:]  # Get the latest 10 emails

    for msg_id in reversed(latest_message_ids):  # Iterate from the latest email
        try:
            status, msg_data = mail.fetch(msg_id, "(RFC822)")
            if status != "OK":
                continue

            msg = email.message_from_bytes(msg_data[0][1])
            subject = msg["Subject"]
            body = ""

            # Handle multipart emails
            if msg.is_multipart():
                for part in msg.walk():
                    if part.get_content_type() == "text/plain":
                        try:
                            body = part.get_payload(decode=True).decode("utf-8")
                        except (UnicodeDecodeError, AttributeError):
                            body = None
                        break
            else:
                try:
                    body = msg.get_payload(decode=True).decode("utf-8")
                except (UnicodeDecodeError, AttributeError):
                    body = None

            # Skip emails that cannot be decoded
            if body is None:
                continue

            # Check for "Approved" in the email body
            if "Approved" in body and (subject == APPROVAL_SUBJECT or subject.startswith(f"Re: {APPROVAL_SUBJECT}")):
                return True, "Approval email found."

        except Exception as e:
            # Ignore and skip problematic emails
            continue

    return False, "No approval email found in the latest 10 emails."

# Wait for approval email
start_time = time.time()
while time.time() - start_time < TIMEOUT:
    try:
        approved, message = check_approval(mail)
        if approved:
            mail.logout()
            print(json.dumps({"success": True, "approved": True, "message": message}))
            sys.exit(0)
    except Exception as e:
        print(json.dumps({"success": False, "message": f"Error checking emails: {e}"}))
        sys.exit(1)

    time.sleep(10)  # Poll every 10 seconds

# Timeout reached
mail.logout()
print(json.dumps({"success": False, "approved": False, "message": "Approval timeout reached"}))
sys.exit(1)



