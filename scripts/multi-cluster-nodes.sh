#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="all"

while getopts "n:" opt; do
  case "$opt" in
    n) ENVIRONMENT="$OPTARG" ;;
    *)
      echo "Usage: $0 -n {dev|prod|all}"
      exit 1
      ;;
  esac
done

PROJECT_ID="project-19d98bfe-795f-49b8-af0"
REGION="us-central1"

show_nodes() {
  local cluster="$1"

  gcloud container clusters get-credentials "$cluster" \
    --region "$REGION" \
    --project "$PROJECT_ID" >/dev/null

  echo
  echo "========================================="
  echo "Cluster: $cluster"
  echo "========================================="
  kubectl get nodes -o wide
}

case "$ENVIRONMENT" in
  dev)
    show_nodes "kfounding-dev"
    ;;
  prod)
    show_nodes "kfounding-prod"
    ;;
  all)
    show_nodes "kfounding-dev"
    show_nodes "kfounding-prod"
    ;;
  *)
    echo "Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 -n {dev|prod|all}"
    exit 1
    ;;
esac
