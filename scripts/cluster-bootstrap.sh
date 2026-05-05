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
ZONE="us-central1-a"

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
  --zone "$ZONE" \
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

kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

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
# Validate required env vars
########################################
: "${ARGOCD_REPO_URL:?Need ARGOCD_REPO_URL}"
: "${ARGOCD_REPO_USERNAME:?Need ARGOCD_REPO_USERNAME}"
: "${ARGOCD_REPO_PASSWORD:?Need ARGOCD_REPO_PASSWORD}"

########################################
# Create Argo CD repo secret
########################################
echo "Creating Argo CD repository secret..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-microservices-demo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: ${ARGOCD_REPO_URL}
  username: ${ARGOCD_REPO_USERNAME}
  password: ${ARGOCD_REPO_PASSWORD}
EOF

########################################
# Apply Argo CD Applications
########################################
echo "Applying Argo CD applications..."

kubectl apply -f argocd/boutique-app.yaml -n argocd
kubectl apply -f argocd/observability-app.yaml -n argocd
kubectl apply -f argocd/eck-operator-app.yaml -n argocd

########################################
# Wait for ECK operator
########################################
echo "Waiting for ECK operator to become Healthy..."

until [ "$(kubectl get application eck-operator -n argocd -o jsonpath='{.status.health.status}')" = "Healthy" ]; do
  kubectl get application eck-operator -n argocd || true
  sleep 10
done

########################################
# Apply remaining apps
########################################
kubectl apply -f argocd/logging-app.yaml -n argocd
kubectl apply -f argocd/logging-agent-app.yaml -n argocd
kubectl apply -f argocd/tracing-app.yaml -n argocd

echo "Cluster bootstrap completed successfully 🚀"
