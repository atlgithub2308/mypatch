#!/bin/bash

# Enable error handling
set -e

# Read parameters
PROJECT=$PT_project
ZONE=$PT_zone
VM_NAME=$PT_vmname
SNAPSHOT_NAME=$PT_snapshotname

# Ensure gcloud is in PATH
export PATH=$PATH:/usr/local/google-cloud-sdk/bin

# Authenticate using a service account
gcloud auth activate-service-account --key-file=/etc/gcloud/service-account-key.json

# Retrieve the boot disk name of the VM
DISK_NAME=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --project="$PROJECT" --format="get(disks[0].source)" | awk -F'/' '{print $NF}')

if [ -z "$DISK_NAME" ]; then
  echo "Error: Unable to find the boot disk for VM $VM_NAME."
  exit 1
fi

echo "Found boot disk: $DISK_NAME"

# Create an standard snapshot
gcloud compute snapshots create "$SNAPSHOT_NAME" \
  --source-disk="$DISK_NAME" \
  --source-disk-zone="$ZONE" \
  --project="$PROJECT" \
  --snapshot-type=STANDARD \
  --quiet

echo "Snapshot $SNAPSHOT_NAME created successfully!"
