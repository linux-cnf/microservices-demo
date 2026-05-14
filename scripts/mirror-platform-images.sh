#!/usr/bin/env bash
# NOTE:
# This script mirrors approved third-party platform/observability container
# images into the private Google Artifact Registry repository used by the
# GKE cluster.
#
# It was introduced to support private-node cluster designs where nodes should
# avoid direct public image pulls and optionally operate without Cloud NAT.
#
# The script:
# - Reads approved source/target image mappings
# - Pulls images from external registries
# - Pushes them into internal Artifact Registry
# - Skips already mirrored images
#
# Image inventory source:
# terraform/live/main/artifact_registry_seed_platform_images.txt
#
# Main benefits:
# - More reliable deployments
# - Reduced dependency on public registries
# - Better control/security over platform images
# - Supports private GKE networking models
#
# In short:
# External platform images -> internal Artifact Registry mirror
# -> GKE pulls trusted private images only.
set -euo pipefail

IMAGE_FILE="terraform/live/main/artifact_registry_seed_platform_images.txt"

gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

while IFS='|' read -r SOURCE_IMAGE TARGET_IMAGE; do
  if [[ -z "${SOURCE_IMAGE}" || "${SOURCE_IMAGE}" =~ ^# ]]; then
    continue
  fi

  echo "Mirroring ${SOURCE_IMAGE} -> ${TARGET_IMAGE}"

  if gcloud artifacts docker images describe "${TARGET_IMAGE}" >/dev/null 2>&1; then
    echo "Already exists: ${TARGET_IMAGE}"
    continue
  fi

  docker pull "${SOURCE_IMAGE}"
  docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}"
  docker push "${TARGET_IMAGE}"
done < "${IMAGE_FILE}"
