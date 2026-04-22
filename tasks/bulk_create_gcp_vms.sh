#!/bin/bash

# Enable error handling
set -e

# Read parameters
PROJECT=$PT_project
ZONE=$PT_zone
VM_PREFIX=$PT_vm_prefix
COUNT=$PT_count
MACHINE_TYPE=$PT_machine_type
IMAGE_FAMILY=$PT_image_family
IMAGE_PROJECT=$PT_image_project
NETWORK=$PT_network
SUBNET=$PT_subnet
DISK_SIZE_GB=${PT_disk_size_gb:-10}
DISK_TYPE=${PT_disk_type:-pd-standard}

# Ensure gcloud is in PATH
export PATH=$PATH:/usr/local/google-cloud-sdk/bin

# Authenticate using a service account
gcloud auth activate-service-account --key-file=/etc/gcloud/service-account-key.json

# Loop to create VMs
for i in $(seq 1 $COUNT); do
  VMNAME="${VM_PREFIX}-$i"
  echo "Creating VM: $VMNAME"

  gcloud compute instances create "$VMNAME" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --network="$NETWORK" \
    --subnet="$SUBNET" \
    --boot-disk-size="${DISK_SIZE_GB}GB" \
    --boot-disk-type="$DISK_TYPE" \
    --quiet

  echo "VM $VMNAME created successfully!"
done

echo "All VMs created successfully!"