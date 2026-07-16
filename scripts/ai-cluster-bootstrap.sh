#!/usr/bin/env bash
# ---------------------------------------------------------
# PURPOSE:
# Bootstraps the AI Platform through Argo CD.
# Supports branch-aware GitOps deployments for feature, develop,
# and main branches without modifying repository manifests.
# ---------------------------------------------------------
set -euo pipefail

ENVIRONMENT=""
COMMAND="help"
BRANCH="main"

usage() {
  cat <<USAGE
Usage:
  $0 -n prod -b main platform
  $0 -n prod -b develop platform
  $0 -n prod -b feature/ai-infra-release-4 platform

  $0 -n prod -b develop enable-assistant
  $0 -n prod -b develop disable-assistant
  $0 -n prod -b develop all
  $0 -n dev platform   # intentionally blocked for now 

Notes:
  - The AI Application temporarily follows the selected Git branch.
  - No repository manifest changes are required for branch testing.
  - Production releases should use the main branch.
USAGE
}

while getopts "n:b:h" opt; do
  case "$opt" in
    n) ENVIRONMENT="$OPTARG" ;;
    b) BRANCH="$OPTARG" ;;
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
    echo "  $0 -n prod -b develop platform"
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
  echo "Git Branch  : ${BRANCH}"
  echo "Argo CD namespace: ${AI_APP_NAMESPACE}"
  echo
  
  sed "s|targetRevision: .*|targetRevision: ${BRANCH}|g" \
      "${AI_APP_MANIFEST}" \
      | kubectl apply --validate=false -f -

}


wait_for_ai_app() {
  echo "Waiting for ai-platform Argo CD Application..."

  kubectl wait application ai-platform \
    -n "${AI_APP_NAMESPACE}" \
    --for=jsonpath='{.metadata.name}'=ai-platform \
    --timeout=120s

  echo "Waiting for ai-platform to become Synced and Healthy..."
  echo "Note: ai-ollama can take 10-20 minutes during first startup/model preparation."

  for i in {1..40}; do
    sync_status="$(kubectl get application ai-platform -n "${AI_APP_NAMESPACE}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl get application ai-platform -n "${AI_APP_NAMESPACE}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    echo "Attempt ${i}/40: sync=${sync_status:-unknown}, health=${health_status:-unknown}"

    if [ "${sync_status}" = "Synced" ] && [ "${health_status}" = "Healthy" ]; then
      echo "✅ ai-platform is Synced and Healthy."
      return 0
    fi

    echo "Current AI pods:"
    kubectl get pods -n ai || true

    sleep 30
  done

  echo "❌ Timeout waiting for ai-platform."
  echo "Final Argo CD status:"
  kubectl get application ai-platform -n "${AI_APP_NAMESPACE}" -o wide || true

  echo "Final AI pod status:"
  kubectl get pods -n ai -o wide || true

  echo "Recent AI events:"
  kubectl get events -n ai --sort-by=.lastTimestamp | tail -40 || true

  exit 1
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

recommended_validation() {
  echo
  echo "========================================================="
  echo "Recommended AI Platform validation"
  echo "========================================================="

  echo
  echo "AI Platform target Git revision:"
  kubectl get application "${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    -o jsonpath='{.spec.source.targetRevision}{"\n"}' || true

  echo
  echo "AI Platform Argo CD Application status:"
  kubectl get application "${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    -o wide || true

  echo
  echo "All Argo CD Applications:"
  kubectl get applications.argoproj.io \
    -n "${AI_APP_NAMESPACE}" || true

  echo
  echo "AI namespace workloads:"
  kubectl get deploy,statefulset,rollout,job,pods \
    -n ai \
    -o wide || true

  echo
  echo "AI namespace services:"
  kubectl get services \
    -n ai \
    -o wide || true

  echo
  echo "AI namespace persistent volumes:"
  kubectl get pvc \
    -n ai || true

  echo
  echo "AI namespace configuration:"
  kubectl get configmap \
    -n ai || true

  echo
  echo "Recent AI namespace events:"
  kubectl get events \
    -n ai \
    --sort-by=.lastTimestamp \
    | tail -30 || true

  echo
  echo "Recent cluster-wide warning events:"
  kubectl get events \
    -A \
    --field-selector type=Warning \
    --sort-by=.lastTimestamp \
    | tail -30 || true

  echo
  echo "AI pods not currently Running or Completed:"
  kubectl get pods -n ai --no-headers 2>/dev/null \
    | awk '$3 != "Running" && $3 != "Completed" {print}' || true

  echo
  echo "AI Platform validation commands:"
  cat <<EOF

  kubectl get application ${AI_APP_NAME} \\
    -n ${AI_APP_NAMESPACE} \\
    -o jsonpath='{.spec.source.targetRevision}{"\\n"}'

  kubectl get application ${AI_APP_NAME} -n ${AI_APP_NAMESPACE} -o wide
  kubectl get applications.argoproj.io -n ${AI_APP_NAMESPACE}
  kubectl get deploy,statefulset,rollout,job,pods -n ai -o wide
  kubectl get svc,pvc,configmap -n ai
  kubectl get events -n ai --sort-by=.lastTimestamp | tail -30
  kubectl get events -A --field-selector type=Warning \\
    --sort-by=.lastTimestamp | tail -30

EOF

  echo "========================================================="
  echo "AI Platform validation completed."
  echo "========================================================="
}

deploy_platform() {
  echo "Deploying AI Platform through optional GitOps..."

  check_dependencies
  apply_ai_application
  wait_for_ai_app
  check_ai_gateway

  echo
  echo "AI namespace workloads:"
  kubectl get deploy,rollout,pods -n ai

  recommended_validation

  echo
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
