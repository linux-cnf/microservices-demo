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

echo "Waiting for platform-root application to be registered..."

kubectl wait \
  --for=jsonpath='{.metadata.name}'=platform-root \
  application/platform-root \
  -n argocd \
  --timeout=120s || true

echo
echo "========================================================="
echo "GitOps bootstrap initiated successfully"
echo "========================================================="
echo
echo "Argo CD has accepted the root application."
echo "Platform reconciliation is running asynchronously."
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

echo "Bootstrap phase completed."
echo "Argo CD will continue reconciling applications in the background."
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

echo "Cluster bootstrap completed successfully 🚀"
