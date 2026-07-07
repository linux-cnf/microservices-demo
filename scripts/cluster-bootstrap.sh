#!/usr/bin/env bash
# =========================================================
# Environment-Aware Cluster Bootstrap Script (GKE + Argo CD)
# =========================================================
#
# PURPOSE:
# Bootstrap Argo CD into a selected GKE environment.
#
# USAGE:
#   ./scripts/cluster-bootstrap.sh -n dev
#   ./scripts/cluster-bootstrap.sh -n prod
#
# DEV:
# - Cluster: kfounding-dev
# - Argo CD namespace: argocd-dev
# - Root app: platform-root-dev
#
# PROD:
# - Cluster: kfounding-prod
# - Argo CD namespace: argocd
# - Root app: platform-root-prod 
# =========================================================

set -euo pipefail

PROJECT_ID="project-19d98bfe-795f-49b8-af0"
REGION="us-central1"
ENVIRONMENT=""

while getopts "n:" opt; do
  case "$opt" in
    n) ENVIRONMENT="$OPTARG" ;;
    *) echo "Usage: $0 -n dev|prod"; exit 1 ;;
  esac
done

case "$ENVIRONMENT" in
  dev)
    CLUSTER_NAME="kfounding-dev"
    ARGOCD_NAMESPACE="argocd-dev"
    ROOT_APP_FILE="argocd/platform-root-app-dev.yaml"
    ROOT_APP_NAME="platform-root-dev"
    ;;
  prod)
    CLUSTER_NAME="kfounding-prod"
    ARGOCD_NAMESPACE="argocd"
    ROOT_APP_FILE="argocd/platform-root-app-prod.yaml"
    ROOT_APP_NAME="platform-root-prod"	  
    ;;
  *)
    echo "Usage: $0 -n dev|prod"
    exit 1
    ;;
esac

retry() {
  local attempts=5
  local delay=20

  for i in $(seq 1 "$attempts"); do
    "$@" && return 0
    echo "Attempt $i/$attempts failed. Retrying in ${delay}s..."
    sleep "$delay"
  done

  echo "Command failed after ${attempts} attempts: $*"
  return 1
}

on_error() {
  echo "Bootstrap failed at line $1"
  kubectl get pods -n "$ARGOCD_NAMESPACE" || true

  if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    kubectl get application -n "$ARGOCD_NAMESPACE" || true
  fi
}

trap 'on_error $LINENO' ERR

command -v gcloud >/dev/null || { echo "gcloud not installed"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not installed"; exit 1; }
command -v helm >/dev/null || { echo "helm not installed"; exit 1; }

for file in \
  argocd/argocd-cm-health-patch.yaml \
  argocd/argocd-notifications-cm.yaml \
  "$ROOT_APP_FILE" \
  argocd/bootstrap/values.yaml
do
  [[ -f "$file" ]] || { echo "Missing file: $file"; exit 1; }
done

echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Argo CD namespace: $ARGOCD_NAMESPACE"
echo "Root app file: $ROOT_APP_FILE"

gcloud config set project "$PROJECT_ID" >/dev/null

echo "Fetching GKE credentials..."
retry gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID"

echo "Verifying cluster access..."
retry kubectl cluster-info
retry kubectl get nodes -o wide

echo "Installing Argo CD..."
retry bash -c "kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply --validate=false -f -"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo

retry helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --values argocd/bootstrap/values.yaml \
  --wait \
  --timeout 10m

echo "Waiting for Argo CD core components..."

retry kubectl wait --for=condition=Available deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" --timeout=600s

retry kubectl wait --for=condition=Available deployment/argocd-repo-server \
  -n "$ARGOCD_NAMESPACE" --timeout=600s

kubectl wait --for=condition=Available deployment/argocd-applicationset-controller \
  -n "$ARGOCD_NAMESPACE" --timeout=600s || true

kubectl wait --for=condition=Available deployment/argocd-dex-server \
  -n "$ARGOCD_NAMESPACE" --timeout=600s || true

retry kubectl rollout status statefulset/argocd-application-controller \
  -n "$ARGOCD_NAMESPACE" --timeout=600s

echo "Applying Argo CD custom health checks..."
retry bash -c "sed 's/namespace: argocd$/namespace: ${ARGOCD_NAMESPACE}/' argocd/argocd-cm-health-patch.yaml | kubectl apply --validate=false -f -"

echo "Applying Argo CD notifications config..."
retry bash -c "sed 's/namespace: argocd$/namespace: ${ARGOCD_NAMESPACE}/' argocd/argocd-notifications-cm.yaml | kubectl apply --validate=false -f -"

echo "Restarting Argo CD components..."

kubectl rollout restart deployment/argocd-server -n "$ARGOCD_NAMESPACE"
kubectl rollout restart deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"
kubectl rollout restart deployment/argocd-notifications-controller -n "$ARGOCD_NAMESPACE" || true
kubectl rollout restart statefulset/argocd-application-controller -n "$ARGOCD_NAMESPACE"

retry kubectl rollout status deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" --timeout=300s

retry kubectl rollout status deployment/argocd-repo-server \
  -n "$ARGOCD_NAMESPACE" --timeout=300s

kubectl rollout status deployment/argocd-notifications-controller \
  -n "$ARGOCD_NAMESPACE" --timeout=300s || true

retry kubectl rollout status statefulset/argocd-application-controller \
  -n "$ARGOCD_NAMESPACE" --timeout=300s

echo "Applying Argo CD root application..."
retry kubectl apply --validate=false -f "$ROOT_APP_FILE" -n "$ARGOCD_NAMESPACE"

echo "Waiting for root application to be registered..."

kubectl wait \
  --for=jsonpath='{.metadata.name}'="$ROOT_APP_NAME" \
  "application/${ROOT_APP_NAME}" \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=120s || true

echo "Checking root reconciliation status..."

for i in {1..30}; do
  STATUS=$(kubectl get application "$ROOT_APP_NAME" -n "$ARGOCD_NAMESPACE" \
    -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)

  echo "${ROOT_APP_NAME} status: ${STATUS:-not ready}"

  if [[ "$STATUS" == "Synced Healthy" ]]; then
    echo "${ROOT_APP_NAME} is Synced and Healthy."
    break
  fi

  sleep 20
done

echo
echo "========================================================="
echo "GitOps bootstrap submitted successfully"
echo "========================================================="
echo
echo "Environment: $ENVIRONMENT"
echo "Cluster: $CLUSTER_NAME"
echo "Argo CD namespace: $ARGOCD_NAMESPACE"
echo "Root app: $ROOT_APP_NAME"
echo

kubectl get application -n "$ARGOCD_NAMESPACE" || true
kubectl get pods -A || true

echo
echo "Recommended validation:"
echo "  kubectl get application -n ${ARGOCD_NAMESPACE}"
echo "  kubectl get pods -A"
echo "  kubectl get events -A --sort-by=.lastTimestamp | tail -30"
