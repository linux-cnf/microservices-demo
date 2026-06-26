#!/usr/bin/env bash
# =========================================================
# Cluster Bootstrap Script (GKE + Argo CD)
# =========================================================
#
# Purpose:
# Bootstrap Kubernetes cluster from bastion:
# - Connect to private/restricted GKE cluster
# - Install Argo CD
# - Apply Argo CD config
# - Apply root GitOps Application
#
# Run from bastion because GitHub-hosted runners cannot access
# the restricted/private GKE control plane.
#
# Usage:
#   chmod +x scripts/cluster-bootstrap.sh
#   ./scripts/cluster-bootstrap.sh
#
# =========================================================
# Cluster Bootstrap Script (GKE + Argo CD)
# =========================================================

set -euo pipefail

########################################
# Helpers
########################################
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
  echo

  kubectl get pods -n argocd || true
  echo

  if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    kubectl get application -n argocd || true
  else
    echo "Argo CD Application CRD not installed yet."
  fi
}

trap 'on_error $LINENO' ERR

########################################
# Config
########################################
PROJECT_ID="project-19d98bfe-795f-49b8-af0"
CLUSTER_NAME="kfounding"
REGION="us-central1"

########################################
# Preconditions
########################################
command -v gcloud >/dev/null || { echo "gcloud not installed"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not installed"; exit 1; }
command -v helm >/dev/null || { echo "helm not installed"; exit 1; }

for file in \
  argocd/argocd-cm-health-patch.yaml \
  argocd/argocd-notifications-cm.yaml \
  argocd/platform-root-app.yaml
  argocd/bootstrap/values.yaml
do
  [[ -f "$file" ]] || { echo "Missing file: $file"; exit 1; }
done

echo "Using project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null

########################################
# Get GKE credentials
########################################
echo "Fetching GKE credentials..."
retry gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID"

########################################
# Verify access
########################################
echo "Verifying cluster access..."
retry kubectl cluster-info
retry kubectl get nodes -o wide

########################################
# Install Argo CD
########################################
echo "Installing Argo CD..."

retry bash -c 'kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply --validate=false -f -'

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo

retry helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argocd/bootstrap/values.yaml \
  --wait \
  --timeout 10m

########################################
# Wait for Argo CD core components
########################################
echo "Waiting for Argo CD core components..."

retry kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=600s

retry kubectl wait --for=condition=Available deployment/argocd-repo-server \
  -n argocd --timeout=600s

kubectl wait --for=condition=Available deployment/argocd-applicationset-controller \
  -n argocd --timeout=600s || true

kubectl wait --for=condition=Available deployment/argocd-dex-server \
  -n argocd --timeout=600s || true

retry kubectl rollout status statefulset/argocd-application-controller \
  -n argocd --timeout=600s

echo "Argo CD core components are ready."

########################################
# Apply Argo CD configuration
########################################
echo "Applying Argo CD custom health checks..."
retry kubectl apply --validate=false -f argocd/argocd-cm-health-patch.yaml -n argocd

echo "Applying Argo CD notifications config..."
retry kubectl apply --validate=false -f argocd/argocd-notifications-cm.yaml -n argocd

########################################
# Restart Argo CD components
########################################
echo "Restarting Argo CD components to load updated configuration..."

kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-notifications-controller -n argocd || true
kubectl rollout restart statefulset/argocd-application-controller -n argocd

########################################
# Wait after restart
########################################
echo "Waiting for restarted Argo CD components..."

retry kubectl rollout status deployment/argocd-server \
  -n argocd --timeout=300s

retry kubectl rollout status deployment/argocd-repo-server \
  -n argocd --timeout=300s

kubectl rollout status deployment/argocd-notifications-controller \
  -n argocd --timeout=300s || true

retry kubectl rollout status statefulset/argocd-application-controller \
  -n argocd --timeout=300s

########################################
# Apply Argo CD Root Application
########################################
echo "Applying Argo CD root application..."

retry kubectl apply --validate=false -f argocd/platform-root-app.yaml -n argocd

echo "Waiting for platform-root application to be registered..."

kubectl wait \
  --for=jsonpath='{.metadata.name}'=platform-root \
  application/platform-root \
  -n argocd \
  --timeout=120s || true

########################################
# Optional wait for platform-root status
########################################
echo "Checking platform-root reconciliation status..."

for i in {1..30}; do
  STATUS=$(kubectl get application platform-root -n argocd \
    -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)

  echo "platform-root status: ${STATUS:-not ready}"

  if [[ "$STATUS" == "Synced Healthy" ]]; then
    echo "platform-root is Synced and Healthy."
    break
  fi

  sleep 20
done

echo
echo "========================================================="
echo "GitOps bootstrap request submitted successfully"
echo "========================================================="
echo
echo "Argo CD has accepted the root application."
echo "Platform reconciliation may still be running."
echo
echo "Expected bootstrap sequence:"
echo "  platform-root"
echo "      ├── external-secrets"
echo "      ├── eck-operator"
echo "      ├── logging"
echo "      ├── observability"
echo "      ├── tracing"
echo "      └── boutique"
echo
echo "During initial bootstrap it is normal to observe:"
echo "  • OutOfSync applications"
echo "  • Progressing health status"
echo "  • Missing child applications"
echo "  • Operators waiting for CRDs"
echo
echo "Current Argo CD application status:"
echo

kubectl get application -n argocd || true

echo
echo "Applications still converging:"
echo

kubectl get application -n argocd --no-headers 2>/dev/null | \
awk '$2!="Synced" || $3!="Healthy" {
  printf "  - %-30s Sync=%s Health=%s\n",$1,$2,$3
}' || true

echo
echo "Cluster workload summary:"

kubectl get pods -A --no-headers 2>/dev/null | \
awk '
{
  total++
  if ($4=="Running" || $4=="Completed")
    healthy++
}
END {
  printf "  Healthy workloads: %s/%s\n",healthy,total
}'

echo
echo "Recommended validation commands:"
echo
echo "  kubectl get application -A"
echo "  kubectl get pods -A"
echo "  kubectl get events -A --sort-by=.lastTimestamp | tail -30"
echo "  kubectl describe application platform-root -n argocd"
echo

TOTAL_APPS=$(kubectl get application -n argocd --no-headers 2>/dev/null | wc -l || echo 0)

SYNCED_APPS=$(kubectl get application -n argocd --no-headers 2>/dev/null | \
awk '$2=="Synced" {count++} END {print count+0}')

HEALTHY_APPS=$(kubectl get application -n argocd --no-headers 2>/dev/null | \
awk '$3=="Healthy" {count++} END {print count+0}')

echo "Bootstrap Summary"
echo "-----------------"
echo "Applications discovered : ${TOTAL_APPS}"
echo "Applications synced     : ${SYNCED_APPS}"
echo "Applications healthy    : ${HEALTHY_APPS}"
echo

echo "Cluster bootstrap phase completed 🚀"
echo "Argo CD will continue reconciling applications if anything is still pending."
