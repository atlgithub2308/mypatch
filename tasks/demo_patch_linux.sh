#!/bin/bash

# Enable error handling
set -e

# Read parameters
PACKAGE=$PT_package

# Ensure the package name is provided
if [ -z "$PACKAGE" ]; then
  echo "Error: No package specified. Please provide a package name."
  exit 1
fi

echo "Updating package: $PACKAGE"

# Update the specified package in unattended mode
sudo dnf update -y "$PACKAGE"

# Check if the update was successful
if rpm -q "$PACKAGE"; then
  echo "Package $PACKAGE updated successfully!"
else
  echo "Error: Package $PACKAGE update failed!"
  exit 1
fi
