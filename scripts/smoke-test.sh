#!/usr/bin/env bash
# -------------------------------------------------------------------
# PURPOSE:
# Environment-aware smoke test for private GKE platform validation.
#
# USAGE:
#   ./scripts/smoke-test.sh -n dev
#   ./scripts/smoke-test.sh -n prod
#   ./scripts/smoke-test.sh -n shared
#
# NOTE:
# Run this from bastion because GitHub-hosted runners cannot access
# the restricted/private GKE control plane.
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
    ARGOCD_NAMESPACE="argocd-dev"
    ROOT_APP_NAME="platform-root-dev"
    HEALTH_APP_NAME="argocd-health-report-dev"
    ;;
  prod)
    CLUSTER_NAME="kfounding-prod"
    ARGOCD_NAMESPACE="argocd"
    ROOT_APP_NAME="platform-root-prod"
    HEALTH_APP_NAME="argocd-health-report-prod"
    ;;
  shared)
    echo "Shared environment has no GKE cluster or Argo CD workload plane."
    echo "Use Terraform validation for shared:"
    echo "  terraform -chdir=terraform/live/shared validate"
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
echo "Argo CD namespace: ${ARGOCD_NAMESPACE}"

gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Fetching GKE credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" \
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
kubectl get ns "${ARGOCD_NAMESPACE}"

echo "Checking Argo CD rollouts..."
kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s || true
kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo "Checking Argo CD applications..."
kubectl get applications -n "${ARGOCD_NAMESPACE}" || true

echo "Checking root application..."
kubectl get application "${ROOT_APP_NAME}" -n "${ARGOCD_NAMESPACE}"

ROOT_STATUS="$(kubectl get application "${ROOT_APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}{" "}{.status.health.status}')"
echo "${ROOT_APP_NAME}: ${ROOT_STATUS}"

echo "Checking Argo CD health report application..."
kubectl get application "${HEALTH_APP_NAME}" -n "${ARGOCD_NAMESPACE}"

HEALTH_STATUS="$(kubectl get application "${HEALTH_APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.health.status}')"
SYNC_STATUS="$(kubectl get application "${HEALTH_APP_NAME}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}')"

if [[ "${SYNC_STATUS}" != "Synced" || "${HEALTH_STATUS}" != "Healthy" ]]; then
  echo "${HEALTH_APP_NAME} app is not healthy/synced"
  echo "Sync: ${SYNC_STATUS}"
  echo "Health: ${HEALTH_STATUS}"
  exit 1
fi

echo "Checking Argo CD health report CronJob..."
kubectl get cronjob argocd-health-report -n "${ARGOCD_NAMESPACE}"

echo "Checking boutique namespace..."
kubectl get ns boutique || true

echo "Checking frontend service..."
kubectl get svc -n boutique frontend || true

echo "Checking resource usage..."
kubectl top nodes || true
kubectl top pods -A || true

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
  --format="table(name,zone.basename(),sizeGb,type,status)" || true

echo "Smoke test passed for environment: ${ENVIRONMENT}"
