#!/bin/bash

# Define default hostname if not provided
HOSTNAME=${1:-sgdemorocky2.atl88.online}

# Check if the httpd service is running
if systemctl is-active --quiet httpd; then
  # Stop the httpd service
  systemctl stop httpd

  # Check if the service was successfully stopped (exit status 0)
  if [ $? -eq 0 ]; then
    echo "httpd service successfully stopped on $HOSTNAME."
  else
    echo "Failed to stop httpd service on $HOSTNAME."
  fi
else
  echo "httpd service is not running on $HOSTNAME, no action taken."
fi
