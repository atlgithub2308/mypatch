#!/bin/bash

# Enable error handling
set -e

# Read parameters
PROJECT=$PT_project
ZONE=$PT_zone
VMNAMES=$PT_vmnames
SERVICE_ACCOUNT_KEY_FILE=$PT_service_account_key_file
GCLOUD_BIN_PATH=$PT_gcloud_bin_path

# Ensure gcloud is in PATH
export PATH=$PATH:$GCLOUD_BIN_PATH

# Check if key file exists
if [ ! -f "$SERVICE_ACCOUNT_KEY_FILE" ]; then
  echo "Error: Service account key file not found at $SERVICE_ACCOUNT_KEY_FILE"
  exit 1
fi

# Authenticate using a service account
gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY_FILE"

# Loop to delete VMs
for VMNAME in $VMNAMES; do
  echo "Deleting VM: $VMNAME"

  gcloud compute instances delete "$VMNAME" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --quiet

  echo "VM $VMNAME deleted successfully!"
done

echo "All specified VMs deleted successfully!"