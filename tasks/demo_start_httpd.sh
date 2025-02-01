#!/bin/bash

# Define default hostname if not provided
#HOSTNAME=${1:-sgdemorocky3.atl88.online}
HOSTNAME=$PT_hostname

# Check if the httpd service is running
if ! systemctl is-active --quiet httpd; then
  # Start the httpd service
  systemctl start httpd

  # Check if the service was successfully started (exit status 0)
  if [ $? -eq 0 ]; then
    echo "httpd service successfully started on $HOSTNAME."
  else
    echo "Failed to start httpd service on $HOSTNAME."
  fi
else
  echo "httpd service is already running on $HOSTNAME, no action taken."
fi
