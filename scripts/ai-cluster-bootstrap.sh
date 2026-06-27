#!/usr/bin/env bash

set -euo pipefail

AI_APP_MANIFEST="argocd/optional-apps/ai-platform/ai-platform-app.yaml"
LLM_GATEWAY_ADDR="http://ai-llm-gateway.ai.svc.cluster.local:8080"
AI_AGENT_ADDR="http://ai-agent-orchestrator.ai.svc.cluster.local:8080/agent"

usage() {
  cat <<USAGE
Usage:
  $0 platform
  $0 enable-assistant
  $0 disable-assistant
  $0 all
  $0 help
USAGE
}

COMMAND="${1:-help}"

check_dependencies() {
  kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || {
    echo "ERROR: Argo Rollouts CRD is missing."
    exit 1
  }

  command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required."
    exit 1
  }
}

check_ai_gateway() {
  kubectl rollout status deploy/ai-llm-gateway -n ai --timeout=300s
  
  kubectl exec -n ai deploy/ai-llm-gateway -- \
    python -c '
import urllib.request
response = urllib.request.urlopen("http://localhost:8080/readyz")
print(response.read().decode())
'
}

patch_frontend_env() {
  local enable_value="$1"

  kubectl get rollout frontend -n boutique -o json | jq \
    --arg enable_value "${enable_value}" \
    --arg agent_addr "${AI_AGENT_ADDR}" '
    .spec.template.spec.containers |=
    map(
      if .name == "server" then
        .env = (
          (.env // [])
          | map(select(.name != "ENABLE_ASSISTANT" and .name != "LLM_GATEWAY_ADDR"))
          + (
              if $enable_value == "true" then
                [
                  {"name":"ENABLE_ASSISTANT","value":"true"},
		  {"name":"LLM_GATEWAY_ADDR","value":$agent_addr}
                ]
              else
                [
                  {"name":"ENABLE_ASSISTANT","value":"false"}
                ]
              end
            )
        )
      else
        .
      end
    )
    | {spec:{template:{spec:{containers:.spec.template.spec.containers}}}}
  ' | kubectl patch rollout frontend -n boutique --type=merge -p "$(cat)"
}

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

  echo "Checking LLM Gateway readiness..."
  check_ai_gateway

  echo "AI namespace workloads:"
  kubectl get pods -n ai

  echo "✅ AI Platform is ready."
}

enable_assistant() {
  echo "Enabling frontend AI Assistant temporarily..."

  check_dependencies
  check_ai_gateway
  patch_frontend_env "true"

  kubectl argo rollouts get rollout frontend -n boutique
  echo "✅ Frontend AI Assistant enabled temporarily."
}

disable_assistant() {
  echo "Disabling frontend AI Assistant temporarily..."

  check_dependencies
  patch_frontend_env "false"

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
