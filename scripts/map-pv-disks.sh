#!/usr/bin/env bash
# -------------------------------------------------------------------
# PURPOSE:
# Environment-aware utility to map Kubernetes Persistent Volumes (PVs)
# to the underlying Google Cloud persistent disks used by a GKE cluster.
#
# USAGE:
#   ./scripts/map-pv-disks.sh -n dev
#   ./scripts/map-pv-disks.sh -n prod
#   ./scripts/map-pv-disks.sh -n shared
#
# NOTE:
# shared has no GKE workload cluster, so it exits cleanly.
# -------------------------------------------------------------------

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-project-19d98bfe-795f-49b8-af0}"
REGION="${REGION:-us-central1}"
ENVIRONMENT=""

usage() {
  echo "Usage: $0 -n dev|prod|shared"
}

while getopts "n:h" opt; do
  case "$opt" in
    n) ENVIRONMENT="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

case "${ENVIRONMENT}" in
  dev)
    CLUSTER_NAME="kfounding-dev"
    ;;
  prod)
    CLUSTER_NAME="kfounding-prod"
    ;;
  shared)
    echo "Shared environment has no GKE cluster or PVs."
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

echo "Environment: ${ENVIRONMENT}"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Cluster: ${CLUSTER_NAME}"

gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Fetching GKE credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}"

echo "PV | CLAIM | STORAGECLASS | CAPACITY | DISK"
kubectl get pv \
  -o jsonpath='
{range .items[*]}
{.metadata.name}{" | "}
{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{" | "}
{.spec.storageClassName}{" | "}
{.spec.capacity.storage}{" | "}
{.spec.csi.volumeHandle}{"\n"}
{end}'
