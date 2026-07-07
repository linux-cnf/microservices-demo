#!/usr/bin/env bash

set -euo pipefail

ENVIRONMENT=""
COMMAND="help"

usage() {
  cat <<USAGE
Usage:
  $0 -n prod platform
  $0 -n prod enable-assistant
  $0 -n prod disable-assistant
  $0 -n prod all
  $0 -n prod help

Notes:
  - AI platform is currently supported only in prod.
  - Dev AI support can be added later when dev AI infrastructure exists.
USAGE
}

while getopts "n:h" opt; do
  case "$opt" in
    n) ENVIRONMENT="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

shift $((OPTIND - 1))
COMMAND="${1:-help}"

case "${ENVIRONMENT}" in
  prod)
    AI_APP_NAMESPACE="argocd"
    ;;
  dev)
    echo "ERROR: AI platform is currently enabled only in prod."
    echo "Dev AI infrastructure is not available yet."
    echo ""
    echo "Use:"
    echo "  $0 -n prod platform"
    exit 1
    ;;
  "")
    echo "ERROR: Environment is required."
    echo ""
    usage
    exit 1
    ;;
  *)
    echo "ERROR: Invalid environment: ${ENVIRONMENT}"
    echo "Use: dev or prod"
    exit 1
    ;;
esac

AI_APP_NAME="ai-platform"
AI_APP_MANIFEST="argocd/optional-apps/ai-platform/manifests/ai-platform.yaml"
AI_AGENT_ADDR="http://ai-agent-orchestrator.ai.svc.cluster.local:8080/agent"

check_dependencies() {
  kubectl get crd applications.argoproj.io >/dev/null 2>&1 || {
    echo "ERROR: Argo CD Application CRD is missing."
    exit 1
  }

  kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || {
    echo "ERROR: Argo Rollouts CRD is missing."
    exit 1
  }

  command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required."
    exit 1
  }
}

check_rollouts_plugin() {
  kubectl argo rollouts version >/dev/null 2>&1 || {
    echo "ERROR: kubectl argo rollouts plugin is required."
    exit 1
  }
}

apply_ai_application() {
  [[ -f "${AI_APP_MANIFEST}" ]] || {
    echo "ERROR: Missing AI app manifest: ${AI_APP_MANIFEST}"
    exit 1
  }

  echo "Applying optional AI Platform Argo CD Application..."
  echo "Environment: ${ENVIRONMENT}"
  echo "Argo CD namespace: ${AI_APP_NAMESPACE}"

  kubectl apply --validate=false -f "${AI_APP_MANIFEST}" -n "${AI_APP_NAMESPACE}"
}

wait_for_ai_app() {
  echo "Waiting for ${AI_APP_NAME} Argo CD Application..."

  kubectl wait \
    --for=jsonpath='{.metadata.name}'="${AI_APP_NAME}" \
    "application/${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    --timeout=180s

  echo "Waiting for ${AI_APP_NAME} app to sync..."
  kubectl wait "application/${AI_APP_NAME}" -n "${AI_APP_NAMESPACE}" \
    --for=jsonpath='{.status.sync.status}'=Synced \
    --timeout=300s

  echo "Waiting for ${AI_APP_NAME} app to become healthy..."
  kubectl wait "application/${AI_APP_NAME}" -n "${AI_APP_NAMESPACE}" \
    --for=jsonpath='{.status.health.status}'=Healthy \
    --timeout=600s
}

check_ai_gateway() {
  echo "Checking LLM Gateway readiness..."

  if kubectl get rollout ai-llm-gateway -n ai >/dev/null 2>&1; then
    echo "Detected ai-llm-gateway as Argo Rollout."
    check_rollouts_plugin
    kubectl argo rollouts status ai-llm-gateway -n ai --timeout=300s

  elif kubectl get deployment ai-llm-gateway -n ai >/dev/null 2>&1; then
    echo "Detected ai-llm-gateway as Kubernetes Deployment."
    kubectl rollout status deployment/ai-llm-gateway -n ai --timeout=300s

  else
    echo "ERROR: ai-llm-gateway not found as Deployment or Rollout."
    kubectl get deploy,rollout,pods -n ai || true
    exit 1
  fi

  local gateway_pod
  gateway_pod="$(kubectl get pod -n ai -l app=ai-llm-gateway \
    -o jsonpath='{.items[0].metadata.name}')"

  echo "Checking ai-llm-gateway /readyz endpoint..."
  kubectl port-forward -n ai "pod/${gateway_pod}" 8080:8080 >/tmp/ai-llm-gateway-port-forward.log 2>&1 &
  local pf_pid=$!

  sleep 5

  python -c '
import urllib.request
response = urllib.request.urlopen("http://localhost:8080/readyz")
print(response.read().decode())
'

  kill "${pf_pid}" >/dev/null 2>&1 || true
}

patch_frontend_env() {
  local enable_value="$1"

  check_rollouts_plugin

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
  echo "Deploying AI Platform through optional GitOps..."

  check_dependencies
  apply_ai_application
  wait_for_ai_app
  check_ai_gateway

  echo "AI namespace workloads:"
  kubectl get deploy,rollout,pods -n ai

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
