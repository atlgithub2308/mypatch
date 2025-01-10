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

# Parameters
APPROVAL_SUBJECT = sys.argv[1]  # Subject to search for approval emails
TIMEOUT = int(sys.argv[2])  # Timeout in seconds

# Connect to the email server
try:
    mail = imaplib.IMAP4_SSL(IMAP_SERVER)
    mail.login(EMAIL, PASSWORD)
    mail.select("inbox")
except Exception as e:
    print(json.dumps({"success": False, "message": f"Failed to connect to email server: {e}"}))
    sys.exit(1)

# Function to check for approval
def check_approval(mail):
    # Search for emails matching the subject
    status, messages = mail.search(None, 'ALL')
    if status != "OK":
        return False, "Failed to search emails."

    for msg_id in reversed(messages[0].split()):  # Iterate from the latest email
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
                    body = part.get_payload(decode=True).decode()
                    break
        else:
            body = msg.get_payload(decode=True).decode()

        # Check for "Approved" in the email body
        if "Approved" in body and (subject == APPROVAL_SUBJECT or subject.startswith(f"Re: {APPROVAL_SUBJECT}")):
            return True, "Approval email found."

    return False, "No approval email found."

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


