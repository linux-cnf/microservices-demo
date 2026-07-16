#!/usr/bin/env bash
# =========================================================
# Environment and Branch-Aware Cluster Bootstrap
# =========================================================
#
# PURPOSE:
# Bootstrap Argo CD into a selected GKE environment and configure
# the root Application to reconcile from a selected Git branch.
#
# USAGE:
#   ./scripts/cluster-bootstrap.sh -n dev  -b develop
#   ./scripts/cluster-bootstrap.sh -n prod -b develop
#   ./scripts/cluster-bootstrap.sh -n prod -b main
#
# OPTIONS:
#   -n  Environment: dev or prod
#   -b  Git branch/revision: develop, main, release/*, feature/*, etc.
#
# EXAMPLES:
#
# Development cluster using develop:
#   ./scripts/cluster-bootstrap.sh -n dev -b develop
#
# Temporary production lab using develop:
#   ./scripts/cluster-bootstrap.sh -n prod -b develop
#
# Production release using main:
#   ./scripts/cluster-bootstrap.sh -n prod -b main
#
# IMPORTANT:
# The script does not modify the tracked root Application file.
# It creates a temporary rendered manifest with the requested
# targetRevision and applies that manifest to the cluster.
# =========================================================

set -euo pipefail

PROJECT_ID="project-19d98bfe-795f-49b8-af0"
REGION="us-central1"

ENVIRONMENT=""
GIT_REVISION=""

usage() {
  cat <<EOF
Usage:
  $0 -n dev|prod -b <git-revision>

Examples:
  $0 -n dev -b develop
  $0 -n prod -b develop
  $0 -n prod -b main
EOF
}

while getopts ":n:b:" opt; do
  case "$opt" in
    n)
      ENVIRONMENT="$OPTARG"
      ;;
    b)
      GIT_REVISION="$OPTARG"
      ;;
    :)
      echo "ERROR: Option -$OPTARG requires a value."
      usage
      exit 1
      ;;
    \?)
      echo "ERROR: Invalid option: -$OPTARG"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ENVIRONMENT" || -z "$GIT_REVISION" ]]; then
  echo "ERROR: Both environment and Git revision are required."
  usage
  exit 1
fi

# Allow common Git revision formats while blocking shell-sensitive input.
if [[ ! "$GIT_REVISION" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "ERROR: Invalid Git revision: $GIT_REVISION"
  exit 1
fi

case "$ENVIRONMENT" in
  dev)
    CLUSTER_NAME="kfounding-dev"
    ARGOCD_NAMESPACE="argocd-dev"
    ROOT_APP_FILE="argocd/platform-root-app-dev.yaml"
    ROOT_APP_NAME="platform-root-dev"
    ;;
  prod)
    CLUSTER_NAME="kfounding-prod"
    ARGOCD_NAMESPACE="argocd"
    ROOT_APP_FILE="argocd/platform-root-app-prod.yaml"
    ROOT_APP_NAME="platform-root-prod"
    ;;
  *)
    echo "ERROR: Unsupported environment: $ENVIRONMENT"
    usage
    exit 1
    ;;
esac

RENDERED_ROOT_APP=""

cleanup() {
  if [[ -n "${RENDERED_ROOT_APP:-}" && -f "$RENDERED_ROOT_APP" ]]; then
    rm -f "$RENDERED_ROOT_APP"
  fi
}

trap cleanup EXIT

retry() {
  local attempts=5
  local delay=20
  local attempt

  for attempt in $(seq 1 "$attempts"); do
    if "$@"; then
      return 0
    fi

    echo "Attempt ${attempt}/${attempts} failed. Retrying in ${delay}s..."
    sleep "$delay"
  done

  echo "ERROR: Command failed after ${attempts} attempts: $*"
  return 1
}

on_error() {
  local line_number="$1"

  echo
  echo "Bootstrap failed at line ${line_number}."

  kubectl get pods -n "$ARGOCD_NAMESPACE" || true

  if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
    kubectl get applications.argoproj.io \
      -n "$ARGOCD_NAMESPACE" || true
  fi
}

trap 'on_error $LINENO' ERR

command -v gcloud >/dev/null 2>&1 || {
  echo "ERROR: gcloud is not installed."
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl is not installed."
  exit 1
}

command -v helm >/dev/null 2>&1 || {
  echo "ERROR: helm is not installed."
  exit 1
}

for file in \
  argocd/argocd-cm-health-patch.yaml \
  argocd/argocd-notifications-cm.yaml \
  "$ROOT_APP_FILE" \
  argocd/bootstrap/values.yaml
do
  [[ -f "$file" ]] || {
    echo "ERROR: Missing required file: $file"
    exit 1
  }
done

echo "========================================================="
echo "Cluster bootstrap configuration"
echo "========================================================="
echo "Environment:          $ENVIRONMENT"
echo "Project:              $PROJECT_ID"
echo "Region:               $REGION"
echo "Cluster:              $CLUSTER_NAME"
echo "Argo CD namespace:    $ARGOCD_NAMESPACE"
echo "Root application:     $ROOT_APP_NAME"
echo "Root application file:$ROOT_APP_FILE"
echo "Git revision:         $GIT_REVISION"
echo "========================================================="

gcloud config set project "$PROJECT_ID" >/dev/null

echo "Fetching GKE credentials..."

retry gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID"

echo "Verifying cluster access..."

retry kubectl cluster-info
retry kubectl get nodes -o wide

echo "Creating Argo CD namespace..."

retry bash -c \
  "kubectl create namespace '${ARGOCD_NAMESPACE}' \
  --dry-run=client -o yaml |
  kubectl apply --validate=false -f -"

echo "Installing or upgrading Argo CD..."

helm repo add argo https://argoproj.github.io/argo-helm \
  >/dev/null 2>&1 || true

helm repo update argo

retry helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --values argocd/bootstrap/values.yaml \
  --wait \
  --timeout 10m

echo "Waiting for Argo CD core components..."

retry kubectl wait \
  --for=condition=Available \
  deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=600s

retry kubectl wait \
  --for=condition=Available \
  deployment/argocd-repo-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=600s

kubectl wait \
  --for=condition=Available \
  deployment/argocd-applicationset-controller \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=600s || true

kubectl wait \
  --for=condition=Available \
  deployment/argocd-dex-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=600s || true

retry kubectl rollout status \
  statefulset/argocd-application-controller \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=600s

echo "Applying Argo CD custom health checks..."

retry bash -c \
  "sed 's/namespace: argocd$/namespace: ${ARGOCD_NAMESPACE}/' \
  argocd/argocd-cm-health-patch.yaml |
  kubectl apply --validate=false -f -"

echo "Applying Argo CD notifications configuration..."

retry bash -c \
  "sed 's/namespace: argocd$/namespace: ${ARGOCD_NAMESPACE}/' \
  argocd/argocd-notifications-cm.yaml |
  kubectl apply --validate=false -f -"

echo "Restarting Argo CD components..."

kubectl rollout restart deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE"

kubectl rollout restart deployment/argocd-repo-server \
  -n "$ARGOCD_NAMESPACE"

kubectl rollout restart deployment/argocd-notifications-controller \
  -n "$ARGOCD_NAMESPACE" || true

kubectl rollout restart statefulset/argocd-application-controller \
  -n "$ARGOCD_NAMESPACE"

retry kubectl rollout status deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=300s

retry kubectl rollout status deployment/argocd-repo-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=300s

kubectl rollout status deployment/argocd-notifications-controller \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=300s || true

retry kubectl rollout status statefulset/argocd-application-controller \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=300s

echo "Rendering root Application for Git revision: $GIT_REVISION"

RENDERED_ROOT_APP="$(mktemp)"

# Replace the root Application source revision without modifying the
# repository file. The first targetRevision field belongs to spec.source.
awk -v revision="$GIT_REVISION" '
  BEGIN {
    replaced = 0
  }

  /^[[:space:]]*targetRevision:[[:space:]]*/ && replaced == 0 {
    indentation = $0
    sub(/targetRevision:.*/, "", indentation)
    print indentation "targetRevision: " revision
    replaced = 1
    next
  }

  {
    print
  }

  END {
    if (replaced == 0) {
      exit 42
    }
  }
' "$ROOT_APP_FILE" >"$RENDERED_ROOT_APP" || {
  echo "ERROR: Could not update targetRevision in $ROOT_APP_FILE"
  exit 1
}

echo "Rendered root Application source:"
grep -E \
  "repoURL:|targetRevision:|path:" \
  "$RENDERED_ROOT_APP" || true

echo "Applying Argo CD root Application..."

retry kubectl apply \
  --validate=false \
  -f "$RENDERED_ROOT_APP"

echo "Waiting for root Application to be registered..."

kubectl wait \
  --for=jsonpath='{.metadata.name}'="$ROOT_APP_NAME" \
  "application/${ROOT_APP_NAME}" \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=120s || true

echo "Verifying configured Git revision..."

APPLIED_REVISION="$(
  kubectl get application "$ROOT_APP_NAME" \
    -n "$ARGOCD_NAMESPACE" \
    -o jsonpath='{.spec.source.targetRevision}'
)"

if [[ "$APPLIED_REVISION" != "$GIT_REVISION" ]]; then
  echo "ERROR: Root Application revision mismatch."
  echo "Expected: $GIT_REVISION"
  echo "Actual:   $APPLIED_REVISION"
  exit 1
fi

echo "Root Application is configured for: $APPLIED_REVISION"

echo "Waiting for root Application reconciliation..."

ROOT_HEALTHY=false

for attempt in $(seq 1 30); do
  STATUS="$(
    kubectl get application "$ROOT_APP_NAME" \
      -n "$ARGOCD_NAMESPACE" \
      -o jsonpath='{.status.sync.status} {.status.health.status}' \
      2>/dev/null || true
  )"

  echo "Attempt ${attempt}/30 — ${ROOT_APP_NAME}: ${STATUS:-not ready}"

  if [[ "$STATUS" == "Synced Healthy" ]]; then
    ROOT_HEALTHY=true
    break
  fi

  sleep 20
done

if [[ "$ROOT_HEALTHY" != "true" ]]; then
  echo "WARNING: Root Application did not become Synced and Healthy"
  echo "within the waiting period."
  echo
  kubectl get application "$ROOT_APP_NAME" \
    -n "$ARGOCD_NAMESPACE" \
    -o yaml || true
fi

echo
echo "========================================================="
echo "GitOps bootstrap submitted successfully"
echo "========================================================="
echo "Environment:       $ENVIRONMENT"
echo "Cluster:           $CLUSTER_NAME"
echo "Argo CD namespace: $ARGOCD_NAMESPACE"
echo "Root application:  $ROOT_APP_NAME"
echo "Git revision:      $GIT_REVISION"
echo "========================================================="
echo

kubectl get applications.argoproj.io \
  -n "$ARGOCD_NAMESPACE" || true

kubectl get pods -A || true

echo
echo "Recommended validation:"
echo
echo "  kubectl get application ${ROOT_APP_NAME} \\"
echo "    -n ${ARGOCD_NAMESPACE} \\"
echo "    -o jsonpath='{.spec.source.targetRevision}{\"\\n\"}'"
echo
echo "  kubectl get applications.argoproj.io -n ${ARGOCD_NAMESPACE}"
echo "  kubectl get pods -A"
echo "  kubectl get events -A --sort-by=.lastTimestamp | tail -30"
