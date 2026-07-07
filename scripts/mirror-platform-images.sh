#!/usr/bin/env bash
# Mirrors approved third-party images into private Artifact Registry.
#
# Usage:
#   ./scripts/mirror-platform-images.sh -n dev
#   ./scripts/mirror-platform-images.sh -n prod
#   ./scripts/mirror-platform-images.sh -n shared
#
# NOTE:
# shared has no seed files today, so it exits cleanly.
# -------------------------------------------------------------------

set -euo pipefail

ENVIRONMENT=""

usage() {
  echo "Usage: $0 -n dev|prod|shared"
}

while getopts "n:h" opt; do
  case "$opt" in
    n) ENVIRONMENT="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

case "${ENVIRONMENT}" in
  dev|prod)
    SEED_DIR="terraform/live/${ENVIRONMENT}"
    ;;
  shared)
    echo "Shared environment has no platform image seed files."
    echo "Nothing to mirror."
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

SEED_FILES=(
  "${SEED_DIR}/artifact_registry_seed_platform_images.txt"
  "${SEED_DIR}/artifact_registry_seed_images.txt"
)

gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

for IMAGE_FILE in "${SEED_FILES[@]}"; do
  if [[ ! -f "${IMAGE_FILE}" ]]; then
    echo "Seed file not found, skipping: ${IMAGE_FILE}"
    continue
  fi

  echo "========================================================="
  echo "Environment: ${ENVIRONMENT}"
  echo "Processing image seed file: ${IMAGE_FILE}"
  echo "========================================================="

  while IFS='|' read -r SOURCE_IMAGE TARGET_IMAGE; do
    SOURCE_IMAGE="${SOURCE_IMAGE//[$'\t\r\n ']}"
    TARGET_IMAGE="${TARGET_IMAGE//[$'\t\r\n ']}"

    if [[ -z "${SOURCE_IMAGE}" || "${SOURCE_IMAGE}" =~ ^# ]]; then
      continue
    fi

    if [[ -z "${TARGET_IMAGE}" ]]; then
      echo "Invalid mapping in ${IMAGE_FILE}: missing target image for ${SOURCE_IMAGE}"
      exit 1
    fi

    echo "Mirroring ${SOURCE_IMAGE} -> ${TARGET_IMAGE}"

    if gcloud artifacts docker images describe "${TARGET_IMAGE}" >/dev/null 2>&1; then
      echo "Already exists: ${TARGET_IMAGE}"
      continue
    fi

    docker pull "${SOURCE_IMAGE}"
    docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}"
    docker push "${TARGET_IMAGE}"

    echo "Mirrored successfully: ${TARGET_IMAGE}"
  done < "${IMAGE_FILE}"
done

echo "Image mirroring completed successfully for environment: ${ENVIRONMENT}"
