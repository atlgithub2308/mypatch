#!/bin/bash

# Parameters
EMAIL="$PT_email"
SUBJECT="$PT_subject"
MESSAGE="$PT_message"

# Check if mailx is installed
if ! command -v mailx &>/dev/null; then
  echo '{"success": false, "message": "mailx is not installed"}' >&2
  exit 1
fi

# Send the email
echo "$MESSAGE" | mailx -s "$SUBJECT" "$EMAIL"

# Check the exit status of the mail command
if [ $? -eq 0 ]; then
  echo '{"success": true, "message": "Notification sent successfully"}'
else
  echo '{"success": false, "message": "Failed to send notification"}' >&2
  exit 1
fi
