#!/usr/bin/env bash

# =========================================================
# AI Cluster Bootstrap Script
# =========================================================
#
# PURPOSE:
# Manage optional AI platform and frontend AI Assistant toggle.
#
# COMMANDS:
# ./scripts/ai-cluster-bootstrap.sh platform
#   Deploy AI infra/workloads only.
#
# ./scripts/ai-cluster-bootstrap.sh enable-assistant
#   Temporarily enable frontend AI chat in live cluster.
#
# ./scripts/ai-cluster-bootstrap.sh disable-assistant
#   Temporarily disable frontend AI chat in live cluster.
#
# ./scripts/ai-cluster-bootstrap.sh all
#   Deploy AI platform and enable frontend AI chat.
#
# NOTE:
# enable-assistant/disable-assistant use live kubectl patching.
# For permanent production enablement, use GitOps/PR.
# =========================================================

set -euo pipefail

COMMAND="${1:-platform}"
AI_APP_MANIFEST="argocd/optional-apps/ai-platform/ai-platform-app.yaml"
LLM_GATEWAY_ADDR="http://ai-llm-gateway.ai.svc.cluster.local:8080"

deploy_platform() {
  echo "Deploying optional AI Platform through Argo CD..."

  if [ ! -f "${AI_APP_MANIFEST}" ]; then
    echo "ERROR: Missing ${AI_APP_MANIFEST}"
    exit 1
  fi

  kubectl apply -n argocd -f "${AI_APP_MANIFEST}"

  kubectl wait \
    --for=jsonpath='{.metadata.name}'=ai-platform \
    application/ai-platform \
    -n argocd \
    --timeout=120s || true

  echo "Waiting for AI LLM Gateway rollout..."
  kubectl rollout status deploy/ai-llm-gateway -n ai --timeout=300s

  echo "Checking LLM Gateway readiness..."
  kubectl run ai-gateway-check -n ai --rm -i --restart=Never \
    --image=curlimages/curl -- \
    curl -fsS "${LLM_GATEWAY_ADDR}/readyz"

  echo "AI namespace workloads:"
  kubectl get pods -n ai

  echo "✅ AI Platform is ready."
}

enable_assistant() {
  echo "Enabling frontend AI Assistant temporarily..."

  kubectl rollout status deploy/ai-llm-gateway -n ai --timeout=300s

  kubectl run ai-gateway-check -n ai --rm -i --restart=Never \
    --image=curlimages/curl -- \
    curl -fsS "${LLM_GATEWAY_ADDR}/readyz"

  kubectl -n boutique set env rollout/frontend \
    ENABLE_ASSISTANT=true \
    LLM_GATEWAY_ADDR="${LLM_GATEWAY_ADDR}"

  kubectl argo rollouts get rollout frontend -n boutique
  echo "✅ Frontend AI Assistant enabled temporarily."
}

disable_assistant() {
  echo "Disabling frontend AI Assistant temporarily..."

  kubectl -n boutique set env rollout/frontend \
    ENABLE_ASSISTANT=false \
    LLM_GATEWAY_ADDR-

  kubectl argo rollouts get rollout frontend -n boutique
  echo "✅ Frontend AI Assistant disabled temporarily."
}

case "${COMMAND}" in
  platform)
    deploy_platform
    ;;
  enable-assistant)
    enable_assistant
    ;;
  disable-assistant)
    disable_assistant
    ;;
  all)
    deploy_platform
    enable_assistant
    ;;
  *)
    echo "Usage:"
    echo "  $0 platform"
    echo "  $0 enable-assistant"
    echo "  $0 disable-assistant"
    echo "  $0 all"
    exit 1
    ;;
esac
