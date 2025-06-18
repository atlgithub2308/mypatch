#!/bin/bash
# uninstall_postgresql.sh - Puppet Task to uninstall PostgreSQL

set -e

# Stop and disable the service
systemctl stop postgresql || true
systemctl disable postgresql || true

# Remove PostgreSQL packages
dnf remove -y postgresql postgresql-server

# Remove data directory
rm -rf /var/lib/pgsql/data

echo '{"status": "PostgreSQL uninstalled and data removed."}'
