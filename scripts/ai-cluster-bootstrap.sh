#!/usr/bin/env bash

# =========================================================
# AI Cluster Bootstrap Script
# =========================================================
#
# PURPOSE:
# Manage optional AI platform and frontend AI Assistant toggle.
#
# USAGE:
# ./scripts/ai-cluster-bootstrap.sh platform
# ./scripts/ai-cluster-bootstrap.sh enable-assistant
# ./scripts/ai-cluster-bootstrap.sh disable-assistant
# ./scripts/ai-cluster-bootstrap.sh all
# ./scripts/ai-cluster-bootstrap.sh help
#
# NOTE:
# enable-assistant/disable-assistant use live kubectl patching.
# For permanent production enablement, use GitOps/PR.
# =========================================================

set -euo pipefail

AI_APP_MANIFEST="argocd/optional-apps/ai-platform/ai-platform-app.yaml"
LLM_GATEWAY_ADDR="http://ai-llm-gateway.ai.svc.cluster.local:8080"

usage() {
  cat <<EOF
Usage:
  $0 platform            Deploy AI infra/workloads only
  $0 enable-assistant    Enable frontend AI chat temporarily
  $0 disable-assistant   Disable frontend AI chat temporarily
  $0 all                 Deploy AI platform and enable frontend AI chat
  $0 help                Show this help

Examples:
  $0 platform
  $0 all
  $0 enable-assistant
EOF
}

COMMAND="${1:-help}"

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

  echo "Waiting for ai-platform app to sync..."
  kubectl wait application/ai-platform -n argocd \
    --for=jsonpath='{.status.sync.status}'=Synced \
    --timeout=300s

  echo "Waiting for ai-platform app to become healthy..."
  kubectl wait application/ai-platform -n argocd \
    --for=jsonpath='{.status.health.status}'=Healthy \
    --timeout=600s

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
  help|-h|--help)
    usage
    ;;
  *)
    echo "ERROR: Invalid command: ${COMMAND}"
    echo
    usage
    exit 1
    ;;
esac
