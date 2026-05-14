#!/usr/bin/env bash
# NOTE:
# This utility script maps Kubernetes Persistent Volumes (PVs) to the
# underlying Google Cloud persistent disks used by the cluster.
#
# It was added during storage troubleshooting and infrastructure cleanup work,
# especially to identify orphaned GCE persistent disks left behind after
# deleting workloads, namespaces, or clusters.
#
# The script helps correlate:
# Kubernetes PV -> PVC -> StorageClass -> GCE disk volumeHandle
#
# This is useful for:
# - Storage debugging
# - Cost cleanup
# - Identifying orphan disks
# - Safe Terraform/GKE destroy verification
#
# In short:
# Kubernetes storage objects -> underlying GCP disk mapping visibility.
set -euo pipefail

echo "PV | CLAIM | STORAGECLASS | CAPACITY | DISK"
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" | "}{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{" | "}{.spec.storageClassName}{" | "}{.spec.capacity.storage}{" | "}{.spec.csi.volumeHandle}{"\n"}{end}'
