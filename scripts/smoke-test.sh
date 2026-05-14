#!/usr/bin/env bash
# -------------------------------------------------------------------
# PURPOSE:
# Validate that the private GKE platform is actually usable after
# infra provisioning, image mirroring, and cluster bootstrap.
#
# Run this from bastion because GitHub-hosted runners cannot access
# the restricted/private GKE control plane.
# -------------------------------------------------------------------

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-project-9e0b2bd9-4649-487c-9d1}"
CLUSTER_NAME="${CLUSTER_NAME:-kfounding}"
ZONE="${ZONE:-us-central1-a}"

echo "Using project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Fetching GKE credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --zone "${ZONE}" \
  --project "${PROJECT_ID}"

echo "Checking cluster nodes..."
kubectl get nodes -o wide

echo "Checking system pods..."
kubectl get pods -A

echo "Checking failed pods..."
FAILED_PODS="$(kubectl get pods -A --no-headers | grep -E 'ImagePullBackOff|ErrImagePull|CrashLoopBackOff|Pending|CreateContainerConfigError|RunContainerError' || true)"

if [[ -n "${FAILED_PODS}" ]]; then
  echo "Failed pods found:"
  echo "${FAILED_PODS}"
  exit 1
fi

echo "Checking Argo CD namespace..."
kubectl get ns argocd

echo "Checking Argo CD rollouts..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-applicationset-controller -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

echo "Checking Argo CD applications..."
kubectl get applications -n argocd || true

echo "Checking boutique namespace..."
kubectl get ns boutique || true

echo "Checking frontend service..."
kubectl get svc -n boutique frontend || true

echo "Checking PV to GCP disk map..."
if [[ -x "./scripts/map-pv-disks.sh" ]]; then
  ./scripts/map-pv-disks.sh || true
elif [[ -x "./map-pv-disks.sh" ]]; then
  ./map-pv-disks.sh || true
else
  echo "map-pv-disks.sh not found or not executable. Skipping PV map."
fi

echo "Checking GCP pvc-* disks..."
gcloud compute disks list \
  --filter="name~'^pvc-'" \
  --format="table(name,zone.basename(),sizeGb,type,status)"

echo "Smoke test passed."
