#!/usr/bin/env bash
# NOTE:
# This script mirrors approved third-party container images into private
# Google Artifact Registry repositories used by the GKE cluster.
#
# Purpose:
# - Mirror platform/observability images.
# - Mirror required third-party application images such as Redis.
# - Avoid direct public image pulls from private GKE nodes.
# - Skip images that already exist in Artifact Registry.
#
# Image inventory files:
# - terraform/live/main/artifact_registry_seed_platform_images.txt
# - terraform/live/main/artifact_registry_seed_images.txt
#
# Format:
# source_image|target_image
#
# Flow:
# external approved image -> private Artifact Registry mirror
# -> GKE pulls trusted private image only.

set -euo pipefail

SEED_FILES=(
  "terraform/live/main/artifact_registry_seed_platform_images.txt"
  "terraform/live/main/artifact_registry_seed_images.txt"
)

gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

for IMAGE_FILE in "${SEED_FILES[@]}"; do
  if [[ ! -f "${IMAGE_FILE}" ]]; then
    echo "Seed file not found, skipping: ${IMAGE_FILE}"
    continue
  fi

  echo "========================================================="
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

echo "Image mirroring completed successfully."
