#!/usr/bin/env bash
# Builds and runs the Kubernetes Image Auditor against the current kubectl context.
# Images from the configured Google Artifact Registry repositories are considered approved.
# PROJECT_ID and REGION can be overridden through environment variables.
set -euo pipefail

readonly PROJECT_ID="${PROJECT_ID:-project-19d98bfe-795f-49b8-af0}"
readonly REGION="${REGION:-us-central1}"

readonly ALLOWED_PREFIXES="${REGION}-docker.pkg.dev/${PROJECT_ID}/microservices-demo/,${REGION}-docker.pkg.dev/${PROJECT_ID}/platform-observability/,${REGION}-docker.pkg.dev/${PROJECT_ID}/ai-microservices/"

make image-auditor-build

./bin/image-auditor \
  --allowed-prefixes "${ALLOWED_PREFIXES}" \
  "$@"
