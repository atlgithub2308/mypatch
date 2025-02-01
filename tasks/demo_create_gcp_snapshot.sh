#!/bin/bash

# Enable error handling
set -e

# Read parameters
PROJECT=$PT_project
ZONE=$PT_zone
VMNAME=$PT_vmname
SNAPSHOTNAME=$PT_snapshotname
NEW_DISK_NAME="${VMNAME}-snapshot-disk"

# Ensure gcloud is in PATH
export PATH=$PATH:/usr/local/google-cloud-sdk/bin

# Authenticate using a service account
gcloud auth activate-service-account --key-file=/etc/gcloud/service-account-key.json

# Retrieve the boot disk name of the VM
DISK_NAME=$(gcloud compute instances describe "$VMNAME" --zone="$ZONE" --project="$PROJECT" --format="get(disks[0].source)" | awk -F'/' '{print $NF}')

if [ -z "$DISK_NAME" ]; then
  echo "Error: Unable to find the boot disk for VM $VMNAME."
  exit 1
fi

echo "Found boot disk: $DISK_NAME"

# Create an standard snapshot
gcloud compute snapshots create "$SNAPSHOTNAME" \
  --source-disk="$DISK_NAME" \
  --source-disk-zone="$ZONE" \
  --project="$PROJECT" \
  --snapshot-type=STANDARD \
  --quiet

echo "Snapshot $SNAPSHOTNAME created successfully!"

# Create a disk from the snapshot
gcloud compute disks create "$NEW_DISK_NAME" \
  --source-snapshot="$SNAPSHOTNAME" \
  --zone="$ZONE" \
  --project="$PROJECT" \
  --quiet

echo "Disk $NEW_DISK_NAME created successfully from snapshot $SNAPSHOTNAME!"