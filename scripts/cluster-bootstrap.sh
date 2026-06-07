#!/usr/bin/env bash
# =========================================================
# Cluster Bootstrap Script (GKE + Argo CD)
# =========================================================
#
# WHY THIS SCRIPT?
# This script is used to bootstrap the Kubernetes cluster
# (install Argo CD and deploy apps) from a bastion host.
#
# We use bastion because:
# - GKE control plane access is restricted (master authorized networks)
# - GitHub-hosted runners cannot access private/restricted clusters
# - Bastion is already whitelisted and secure
#
# One-liner:
# Run Kubernetes bootstrap (Argo CD + apps) from bastion where cluster access is allowed.
#
# =========================================================
# HOW TO USE
# =========================================================
#
# 1. Login & set project (only once)
#    gcloud auth login
#    gcloud config set project <PROJECT_ID>
#
# 2. Export required variables
#    export ARGOCD_REPO_URL="your_repo_url"
#    export ARGOCD_REPO_USERNAME="your_username"
#    export ARGOCD_REPO_PASSWORD="your_password"
#
# 3. Make script executable
#    chmod +x scripts/cluster-bootstrap.sh
#
# 4. Run script
#    ./scripts/cluster-bootstrap.sh
#
# =========================================================
# SUMMARY
# =========================================================
#
# infra-main (GitHub runner):
#   → Creates cloud infra (VPC, GKE, Artifact Registry)
#
# this script (bastion):
#   → Connects to GKE
#   → Installs Argo CD
#   → Bootstraps applications
#
# Later (optional):
#   → Replace this script with GitHub self-hosted runner on bastion
#
# =========================================================
set -euo pipefail

########################################
# Config (edit if needed)
########################################
PROJECT_ID="project-9e0b2bd9-4649-487c-9d1"
CLUSTER_NAME="kfounding"
REGION="us-central1"

########################################
# Preconditions check
########################################
command -v gcloud >/dev/null || { echo "gcloud not installed"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl not installed"; exit 1; }

echo "Using project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null

########################################
# Get GKE credentials
########################################
echo "Fetching GKE credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "${REGION}" \
  --project "$PROJECT_ID"

########################################
# Verify access
########################################
echo "Verifying cluster access..."
kubectl cluster-info
kubectl get nodes -o wide

########################################
# Install Argo CD
########################################
echo "Installing Argo CD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

#kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply --server-side --force-conflicts -n argocd \
  -f argocd/install.yaml

########################################
# Wait for Argo CD
########################################
echo "Waiting for Argo CD components..."

kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=600s

kubectl wait --for=condition=Available deployment/argocd-repo-server \
  -n argocd --timeout=600s

echo "Argo CD is ready."

########################################
# Apply Argo CD custom health checks
########################################
echo "Applying Argo CD custom health checks..."
kubectl apply -f argocd/argocd-cm-health-patch.yaml -n argocd

########################################
# Apply Argo CD notifications config
########################################
echo "Applying Argo CD notifications config..."
kubectl apply -f argocd/argocd-notifications-cm.yaml -n argocd

########################################
# Restart Argo CD components
########################################
echo "Restarting Argo CD components to load updated configuration..."

kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-notifications-controller -n argocd
kubectl rollout restart statefulset/argocd-application-controller -n argocd

########################################
# Wait for Argo CD components
########################################
kubectl rollout status deployment/argocd-server \
  -n argocd --timeout=300s

kubectl rollout status deployment/argocd-repo-server \
  -n argocd --timeout=300s

kubectl rollout status deployment/argocd-notifications-controller \
  -n argocd --timeout=300s

kubectl rollout status statefulset/argocd-application-controller \
  -n argocd --timeout=300s

########################################
# Public Git repository
########################################
echo "Using public Git repository; no Argo CD repo credentials required."

########################################
# Apply Argo CD Root Application
########################################
echo "Applying Argo CD root application..."

kubectl apply -f argocd/platform-root-app.yaml -n argocd

echo "Waiting for platform-root application to be created..."
kubectl wait --for=jsonpath='{.metadata.name}'=platform-root \
  application/platform-root -n argocd --timeout=120s || true

echo "Waiting for platform-root to sync..."
kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
  application/platform-root -n argocd --timeout=300s || true

echo "Current Argo CD applications:"
kubectl get application -n argocd || true

echo "Checking argocd-health-report application..."

if ! kubectl get application argocd-health-report -n argocd >/dev/null 2>&1; then
  echo "argocd-health-report application not found"
  exit 1
fi

ARGO_SYNC_STATUS="$(kubectl get application argocd-health-report -n argocd -o jsonpath='{.status.sync.status}')"
ARGO_HEALTH_STATUS="$(kubectl get application argocd-health-report -n argocd -o jsonpath='{.status.health.status}')"

echo "argocd-health-report status: Sync=${ARGO_SYNC_STATUS}, Health=${ARGO_HEALTH_STATUS}"

if [[ "${ARGO_SYNC_STATUS}" != "Synced" || "${ARGO_HEALTH_STATUS}" != "Healthy" ]]; then
  echo "argocd-health-report application is not Synced/Healthy"
  exit 1
fi

echo "Checking argocd-health-report CronJob..."

if ! kubectl get cronjob argocd-health-report -n argocd >/dev/null 2>&1; then
  echo "argocd-health-report CronJob not found"
  exit 1
fi

echo "Current Argo CD projects:"
kubectl get appproject -n argocd || true

echo "Cluster bootstrap completed successfully 🚀"
