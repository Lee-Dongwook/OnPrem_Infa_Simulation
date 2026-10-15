#!/bin/bash

echo "Creating Kubernetes Control Plane VM..."
multipass launch 24.04 --name k8s-control-plane --cpus 2 --memory 3G --disk 10G

echo "Creating Kubernetes Worker 1 VM..."
multipass launch 24.04 --name k8s-worker-01 --cpus 1 --memory 2G --disk 10G

echo "Creating Kubernetes Worker 2 VM..."
multipass launch 24.04 --name k8s-worker-02 --cpus 1 --memory 2G --disk 10G

echo "All VMs created successfully!"
multipass list

