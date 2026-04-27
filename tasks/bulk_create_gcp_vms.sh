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

# Check if the image family is available in the zone
echo "Checking if image family '$IMAGE_FAMILY' is available in zone '$ZONE'..."
if ! gcloud compute images describe-from-family "$IMAGE_FAMILY" --project="$IMAGE_PROJECT" --zone="$ZONE" >/dev/null 2>&1; then
  echo "WARNING: Image family '$IMAGE_FAMILY' may not be available in zone '$ZONE'"
  echo "Available Windows Server families in windows-cloud project:"
  gcloud compute images list --project=windows-cloud --filter="family~windows-server" --format="table(name,family,status)" --limit=10 2>/dev/null || echo "Could not list images - check your permissions"
  echo ""
fi

# Loop to create VMs
for i in $(seq 1 $COUNT); do
  VMNAME="${VM_PREFIX}-$i"
  echo "Creating VM: $VMNAME"

  if ! gcloud compute instances create "$VMNAME" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --network="$NETWORK" \
    --subnet="$SUBNET" \
    --boot-disk-size="${DISK_SIZE_GB}GB" \
    --boot-disk-type="$DISK_TYPE" \
    --quiet; then
    
    echo "ERROR: Failed to create VM $VMNAME. This may be due to:"
    echo "  - Image family '$IMAGE_FAMILY' not available in zone '$ZONE'"
    echo "  - Try a different zone or image family (e.g., windows-server-2019-dc instead of windows-server-2022-dc)"
    echo "  - Check available images with: gcloud compute images list --project=$IMAGE_PROJECT --filter=\"family:$IMAGE_FAMILY\""
    exit 1
  fi

  echo "VM $VMNAME created successfully!"
done

echo "All VMs created successfully!"