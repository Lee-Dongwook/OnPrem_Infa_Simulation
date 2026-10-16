#!/bin/bash
set -e

echo "=== Installing Longhorn Prerequisites (open-iscsi, nfs-common, etc.) ==="
sudo apt-get update
sudo apt-get install -y open-iscsi nfs-common util-linux grep

echo "=== Enusring iscsid service is enabled and running ==="
sudo systemctl enable iscsid
sudo systemctl start iscsid

echo "=== Longhorn Prerequisites Setup Completed! ==="
