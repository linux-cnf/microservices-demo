#!/usr/bin/env bash

# =========================================================
# AI Cluster Bootstrap Script
# =========================================================
#
# PURPOSE:
# Deploy optional AI platform workloads through Argo CD.
#
# RESPONSIBILITIES:
# - Register optional ai-platform Argo CD Application
# - Keep AI workloads out of the default platform-root sync
# - Allow AI platform deployment only when explicitly requested
#
# COMPONENTS:
# - AI namespace
# - Ollama
# - LLM Gateway
# - AI Agent Orchestrator
# - vLLM future runtime
#
# USAGE:
# chmod +x scripts/ai-cluster-bootstrap.sh
# ./scripts/ai-cluster-bootstrap.sh
#
# In short:
# Bootstrap optional AI workloads through GitOps on demand.
# =========================================================

set -euo pipefail

APP_MANIFEST="argocd/optional-apps/ai-platform/ai-platform-app.yaml"

echo "========================================================="
echo "Deploying optional AI Platform through Argo CD"
echo "========================================================="
echo

if [ ! -f "${APP_MANIFEST}" ]; then
  echo "ERROR: Missing ${APP_MANIFEST}"
  exit 1
fi

echo "Applying AI Platform Argo CD application..."
kubectl apply -n argocd -f "${APP_MANIFEST}"

echo
echo "Waiting for ai-platform application registration..."
kubectl wait \
  --for=jsonpath='{.metadata.name}'=ai-platform \
  application/ai-platform \
  -n argocd \
  --timeout=120s || true

echo
echo "Current Argo CD application status:"
kubectl get application ai-platform -n argocd || true

echo
echo "AI namespace workloads:"
kubectl get pods -n ai || true

echo
echo "✅ AI Platform bootstrap request completed."
echo "Argo CD will continue reconciliation from Git."
