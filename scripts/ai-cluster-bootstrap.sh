#!/usr/bin/env bash

# =========================================================

# AI Platform Bootstrap Script

# =========================================================

#

# Purpose:

# Deploy optional AI platform workloads through Argo CD.

#

# Components:

# - Ollama

# - vLLM (future)

# - LLM Gateway

# - AI Agent Orchestrator

#

# Usage:

# chmod +x scripts/ai-platform-bootstrap.sh

# ./scripts/ai-platform-bootstrap.sh

#

# =========================================================

set -euo pipefail

echo "========================================================="
echo "Deploying AI Platform"
echo "========================================================="
echo

kubectl apply 
-f argocd/optional-apps/ai-platform/ai-platform-app.yaml 
-n argocd

echo
echo "Waiting for AI application registration..."

kubectl wait 
--for=jsonpath='{.metadata.name}'=ai-platform 
application/ai-platform 
-n argocd 
--timeout=120s || true

echo
echo "AI Platform deployment submitted successfully."
echo
echo "Current status:"
kubectl get application ai-platform -n argocd || true

echo
echo "AI namespace workloads:"
kubectl get pods -n ai || true

echo
echo "Bootstrap request completed."
echo "Argo CD will continue reconciliation in the background."

