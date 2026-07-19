#!/usr/bin/env bash
# ---------------------------------------------------------
# PURPOSE:
# Bootstraps the AI Platform through Argo CD.
#
# Supports:
# - Prod-only AI infrastructure
# - Branch-aware GitOps deployments
# - Existing cpu-small and cpu-better model/resource profiles
#
# The repository Application manifest remains unchanged.
# The selected branch and profile path are rendered at runtime
# before the Argo CD Application is applied.
# ---------------------------------------------------------
set -euo pipefail

ENVIRONMENT=""
COMMAND="help"
BRANCH="main"
AI_PROFILE="cpu-small"

usage() {
  cat <<USAGE
Usage:
  $0 -n prod -b main -p cpu-small platform
  $0 -n prod -b main -p cpu-better platform
  $0 -n prod -b develop -p cpu-small platform
  $0 -n prod -b develop -p cpu-better platform
  $0 -n prod -b feature/ai-infra-release-4 -p cpu-better platform

  $0 -n prod -b develop -p cpu-better enable-assistant
  $0 -n prod -b develop -p cpu-better disable-assistant
  $0 -n prod -b develop -p cpu-better all

  $0 -n dev -b develop -p cpu-small platform
    # Intentionally blocked because AI infrastructure is prod-only.

Options:
  -n  Environment. Supported value: prod
  -b  Git branch followed by the AI Argo CD Application
  -p  AI model/resource profile: cpu-small or cpu-better
  -h  Show this help message

Profiles:
  cpu-small:
    Model: tinyllama
    Intended for smaller CPU nodes and lower resource usage.

  cpu-better:
    Model: llama3.2:3b
    Intended for the e2-highmem-4 AI node profile.

Examples:
  Test the prod AI platform from develop using cpu-better:

    $0 -n prod -b develop -p cpu-better platform

  Deploy and temporarily enable the frontend assistant:

    $0 -n prod -b develop -p cpu-better all

  Deploy a released configuration from main:

    $0 -n prod -b main -p cpu-better platform

Notes:
  - AI infrastructure is available only in the prod cluster.
  - The prod cluster may temporarily follow develop for testing.
  - Production releases should follow the main branch.
  - Branch selection and AI profile selection are independent.
  - Existing profile directories are used directly:
      kustomize/ai-platform/models/cpu-small
      kustomize/ai-platform/models/cpu-better
  - The repository Application manifest is not modified at runtime.
USAGE
}

while getopts "n:b:p:h" opt; do
  case "${opt}" in
    n)
      ENVIRONMENT="${OPTARG}"
      ;;
    b)
      BRANCH="${OPTARG}"
      ;;
    p)
      AI_PROFILE="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
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
    echo "Dev AI infrastructure is not available."
    echo
    echo "Use:"
    echo "  $0 -n prod -b develop -p cpu-better platform"
    exit 1
    ;;
  "")
    echo "ERROR: Environment is required."
    echo
    usage
    exit 1
    ;;
  *)
    echo "ERROR: Invalid environment: ${ENVIRONMENT}"
    echo "Supported environment: prod"
    exit 1
    ;;
esac

case "${AI_PROFILE}" in
  cpu-small|cpu-better)
    ;;
  *)
    echo "ERROR: Invalid AI profile: ${AI_PROFILE}"
    echo "Supported profiles:"
    echo "  cpu-small"
    echo "  cpu-better"
    exit 1
    ;;
esac

AI_APP_NAME="ai-platform"
AI_APP_MANIFEST="argocd/optional-apps/ai-platform/manifests/ai-platform.yaml"
AI_KUSTOMIZE_PATH="kustomize/ai-platform/models/${AI_PROFILE}"
AI_AGENT_ADDR="http://ai-agent-orchestrator.ai.svc.cluster.local:8080/agent"

check_dependencies() {
  command -v kubectl >/dev/null 2>&1 || {
    echo "ERROR: kubectl is required."
    exit 1
  }

  command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required."
    exit 1
  }

  kubectl get crd applications.argoproj.io >/dev/null 2>&1 || {
    echo "ERROR: Argo CD Application CRD is missing."
    exit 1
  }

  kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 || {
    echo "ERROR: Argo Rollouts CRD is missing."
    exit 1
  }

  [[ -f "${AI_APP_MANIFEST}" ]] || {
    echo "ERROR: Missing AI Application manifest:"
    echo "  ${AI_APP_MANIFEST}"
    exit 1
  }

  [[ -d "${AI_KUSTOMIZE_PATH}" ]] || {
    echo "ERROR: Missing AI profile directory:"
    echo "  ${AI_KUSTOMIZE_PATH}"
    exit 1
  }

  [[ -f "${AI_KUSTOMIZE_PATH}/kustomization.yaml" ]] || {
    echo "ERROR: Missing profile kustomization:"
    echo "  ${AI_KUSTOMIZE_PATH}/kustomization.yaml"
    exit 1
  }
}

check_rollouts_plugin() {
  kubectl argo rollouts version >/dev/null 2>&1 || {
    echo "ERROR: kubectl argo rollouts plugin is required."
    exit 1
  }
}

validate_ai_profile() {
  echo "Validating AI profile manifests..."
  echo "Profile path: ${AI_KUSTOMIZE_PATH}"

  kubectl kustomize "${AI_KUSTOMIZE_PATH}" \
    | kubectl apply \
        --dry-run=client \
        --validate=false \
        -f - \
        >/dev/null

  local rendered_model
  rendered_model="$(
    kubectl kustomize "${AI_KUSTOMIZE_PATH}" \
      | awk '
          /^kind: ConfigMap$/ {
            in_configmap = 1
            config_name = ""
            next
          }

          in_configmap && /^metadata:$/ {
            next
          }

          in_configmap && /^[[:space:]]+name: ai-model-config$/ {
            config_name = "ai-model-config"
            next
          }

          config_name == "ai-model-config" &&
          /^[[:space:]]+AI_MODEL:/ {
            sub(/^[[:space:]]+AI_MODEL:[[:space:]]*/, "")
            gsub(/"/, "")
            print
            exit
          }

          /^---$/ {
            in_configmap = 0
            config_name = ""
          }
        '
  )"

  echo "AI profile validation passed."

  if [[ -n "${rendered_model}" ]]; then
    echo "Rendered model: ${rendered_model}"
  fi
}

render_ai_application() {
  local output_file="$1"

  sed \
    -e "s|^[[:space:]]*targetRevision:.*|    targetRevision: ${BRANCH}|" \
    -e "s|^[[:space:]]*path:[[:space:]]*\"*kustomize/ai-platform/[^\"[:space:]]*\"*|    path: \"${AI_KUSTOMIZE_PATH}\"|" \
    "${AI_APP_MANIFEST}" \
    > "${output_file}"

  local rendered_branch
  local rendered_path

  rendered_branch="$(
    awk '
      /^[[:space:]]*targetRevision:/ {
        sub(/^[[:space:]]*targetRevision:[[:space:]]*/, "")
        gsub(/"/, "")
        print
        exit
      }
    ' "${output_file}"
  )"

  rendered_path="$(
    awk '
      /^[[:space:]]*path:/ {
        sub(/^[[:space:]]*path:[[:space:]]*/, "")
        gsub(/"/, "")
        print
        exit
      }
    ' "${output_file}"
  )"

  if [[ "${rendered_branch}" != "${BRANCH}" ]]; then
    echo "ERROR: Failed to render targetRevision."
    echo "Expected: ${BRANCH}"
    echo "Rendered: ${rendered_branch:-empty}"
    exit 1
  fi

  if [[ "${rendered_path}" != "${AI_KUSTOMIZE_PATH}" ]]; then
    echo "ERROR: Failed to render AI profile path."
    echo "Expected: ${AI_KUSTOMIZE_PATH}"
    echo "Rendered: ${rendered_path:-empty}"
    exit 1
  fi
}

apply_ai_application() {
  local rendered_manifest

  rendered_manifest="$(mktemp)"
  trap 'rm -f "${rendered_manifest:-}"' RETURN

  render_ai_application "${rendered_manifest}"

  echo "Applying optional AI Platform Argo CD Application..."
  echo "Environment       : ${ENVIRONMENT}"
  echo "Git branch        : ${BRANCH}"
  echo "AI profile        : ${AI_PROFILE}"
  echo "Kustomize path    : ${AI_KUSTOMIZE_PATH}"
  echo "Argo CD namespace : ${AI_APP_NAMESPACE}"
  echo

  kubectl apply \
    --validate=false \
    -f "${rendered_manifest}"

  rm -f "${rendered_manifest}"
  trap - RETURN
}

wait_for_ai_app() {
  echo "Waiting for ${AI_APP_NAME} Argo CD Application..."

  kubectl wait application "${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    --for=jsonpath='{.metadata.name}'="${AI_APP_NAME}" \
    --timeout=120s

  echo "Waiting for ${AI_APP_NAME} to become Synced and Healthy..."
  echo "Note: ai-ollama can take 10-20 minutes during initial model preparation."

  local sync_status=""
  local health_status=""

  for i in {1..40}; do
    sync_status="$(
      kubectl get application "${AI_APP_NAME}" \
        -n "${AI_APP_NAMESPACE}" \
        -o jsonpath='{.status.sync.status}' \
        2>/dev/null || true
    )"

    health_status="$(
      kubectl get application "${AI_APP_NAME}" \
        -n "${AI_APP_NAMESPACE}" \
        -o jsonpath='{.status.health.status}' \
        2>/dev/null || true
    )"

    echo "Attempt ${i}/40: sync=${sync_status:-unknown}, health=${health_status:-unknown}"

    if [[ "${sync_status}" == "Synced" ]] &&
       [[ "${health_status}" == "Healthy" ]]; then
      echo "✅ ${AI_APP_NAME} is Synced and Healthy."
      return 0
    fi

    echo "Current AI pods:"
    kubectl get pods -n ai || true

    sleep 30
  done

  echo "❌ Timeout waiting for ${AI_APP_NAME}."

  echo
  echo "Final Argo CD status:"
  kubectl get application "${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    -o wide || true

  echo
  echo "Final AI pod status:"
  kubectl get pods -n ai -o wide || true

  echo
  echo "Recent AI events:"
  kubectl get events \
    -n ai \
    --sort-by=.lastTimestamp \
    | tail -40 || true

  exit 1
}

check_ai_gateway() {
  echo "Checking LLM Gateway readiness..."

  if kubectl get rollout ai-llm-gateway -n ai >/dev/null 2>&1; then
    echo "Detected ai-llm-gateway as Argo Rollout."

    check_rollouts_plugin

    kubectl argo rollouts status ai-llm-gateway \
      -n ai \
      --timeout=300s

  elif kubectl get deployment ai-llm-gateway -n ai >/dev/null 2>&1; then
    echo "Detected ai-llm-gateway as Kubernetes Deployment."

    kubectl rollout status deployment/ai-llm-gateway \
      -n ai \
      --timeout=300s

  else
    echo "ERROR: ai-llm-gateway was not found as a Deployment or Rollout."
    kubectl get deploy,rollout,pods -n ai || true
    exit 1
  fi

  local gateway_pod
  local pf_pid

  gateway_pod="$(
    kubectl get pod \
      -n ai \
      -l app=ai-llm-gateway \
      -o jsonpath='{.items[0].metadata.name}'
  )"

  if [[ -z "${gateway_pod}" ]]; then
    echo "ERROR: Could not find an ai-llm-gateway pod."
    exit 1
  fi

  echo "Checking ai-llm-gateway /readyz endpoint..."

  kubectl port-forward \
    -n ai \
    "pod/${gateway_pod}" \
    8080:8080 \
    >/tmp/ai-llm-gateway-port-forward.log 2>&1 &

  pf_pid=$!

  cleanup_gateway_port_forward() {
    kill "${pf_pid}" >/dev/null 2>&1 || true
    wait "${pf_pid}" >/dev/null 2>&1 || true
  }

  trap cleanup_gateway_port_forward RETURN

  sleep 5

  python3 - <<'PY'
import urllib.request

response = urllib.request.urlopen(
    "http://localhost:8080/readyz",
    timeout=10,
)
print(response.read().decode())
PY

  cleanup_gateway_port_forward
  trap - RETURN
}

patch_frontend_env() {
  local enable_value="$1"

  check_rollouts_plugin

  kubectl get rollout frontend -n boutique -o json \
    | jq \
        --arg enable_value "${enable_value}" \
        --arg agent_addr "${AI_AGENT_ADDR}" '
          .spec.template.spec.containers |=
          map(
            if .name == "server" then
              .env = (
                (.env // [])
                | map(
                    select(
                      .name != "ENABLE_ASSISTANT" and
                      .name != "LLM_GATEWAY_ADDR"
                    )
                  )
                + (
                    if $enable_value == "true" then
                      [
                        {
                          "name": "ENABLE_ASSISTANT",
                          "value": "true"
                        },
                        {
                          "name": "LLM_GATEWAY_ADDR",
                          "value": $agent_addr
                        }
                      ]
                    else
                      [
                        {
                          "name": "ENABLE_ASSISTANT",
                          "value": "false"
                        }
                      ]
                    end
                  )
              )
            else
              .
            end
          )
          | {
              spec: {
                template: {
                  spec: {
                    containers: .spec.template.spec.containers
                  }
                }
              }
            }
        ' \
    | kubectl patch rollout frontend \
        -n boutique \
        --type=merge \
        --patch-file=/dev/stdin
}

recommended_validation() {
  echo
  echo "========================================================="
  echo "Recommended AI Platform validation"
  echo "========================================================="

  echo
  echo "Expected configuration:"
  echo "  Environment    : ${ENVIRONMENT}"
  echo "  Git branch     : ${BRANCH}"
  echo "  AI profile     : ${AI_PROFILE}"
  echo "  Kustomize path : ${AI_KUSTOMIZE_PATH}"

  echo
  echo "Live AI Platform Git revision:"
  kubectl get application "${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    -o jsonpath='{.spec.source.targetRevision}{"\n"}' || true

  echo
  echo "Live AI Platform Kustomize path:"
  kubectl get application "${AI_APP_NAME}" \
    -n "${AI_APP_NAMESPACE}" \
    -o jsonpath='{.spec.source.path}{"\n"}' || true

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
  echo "Live Ollama resource configuration:"
  kubectl get deployment ai-ollama \
    -n ai \
    -o jsonpath='requests.cpu={.spec.template.spec.containers[?(@.name=="ai-ollama")].resources.requests.cpu}{"\n"}requests.memory={.spec.template.spec.containers[?(@.name=="ai-ollama")].resources.requests.memory}{"\n"}limits.cpu={.spec.template.spec.containers[?(@.name=="ai-ollama")].resources.limits.cpu}{"\n"}limits.memory={.spec.template.spec.containers[?(@.name=="ai-ollama")].resources.limits.memory}{"\n"}' \
    2>/dev/null || true

  echo
  echo "Live Ollama environment configuration:"
  kubectl get deployment ai-ollama \
    -n ai \
    -o jsonpath='{range .spec.template.spec.containers[?(@.name=="ai-ollama")].env[*]}{.name}={.value}{"\n"}{end}' \
    2>/dev/null || true

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
  kubectl get pods \
    -n ai \
    --no-headers \
    2>/dev/null \
    | awk '$3 != "Running" && $3 != "Completed" {print}' || true

  echo
  echo "AI Platform validation commands:"

  cat <<COMMANDS

  kubectl get application ${AI_APP_NAME} \\
    -n ${AI_APP_NAMESPACE} \\
    -o jsonpath='revision={.spec.source.targetRevision}{"\\n"}path={.spec.source.path}{"\\n"}'

  kubectl get application ${AI_APP_NAME} \\
    -n ${AI_APP_NAMESPACE} \\
    -o wide

  kubectl get applications.argoproj.io \\
    -n ${AI_APP_NAMESPACE}

  kubectl get deploy,statefulset,rollout,job,pods \\
    -n ai \\
    -o wide

  kubectl get svc,pvc,configmap \\
    -n ai

  kubectl get deployment ai-ollama \\
    -n ai \\
    -o jsonpath='{range .spec.template.spec.containers[?(@.name=="ai-ollama")]}request-cpu={.resources.requests.cpu} request-memory={.resources.requests.memory} limit-cpu={.resources.limits.cpu} limit-memory={.resources.limits.memory}{"\\n"}{end}'

  kubectl get deployment ai-ollama \\
    -n ai \\
    -o jsonpath='{range .spec.template.spec.containers[?(@.name=="ai-ollama")].env[*]}{.name}={.value}{"\\n"}{end}'

  kubectl get events \\
    -n ai \\
    --sort-by=.lastTimestamp \\
    | tail -30

  kubectl get events \\
    -A \\
    --field-selector type=Warning \\
    --sort-by=.lastTimestamp \\
    | tail -30

COMMANDS

  echo "========================================================="
  echo "AI Platform validation completed."
  echo "========================================================="
}

deploy_platform() {
  echo "Deploying AI Platform through optional GitOps..."
  echo "Selected profile: ${AI_PROFILE}"
  echo "Selected path   : ${AI_KUSTOMIZE_PATH}"
  echo

  check_dependencies
  validate_ai_profile
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
