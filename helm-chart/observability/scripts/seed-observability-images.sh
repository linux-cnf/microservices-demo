#!/usr/bin/env bash
set -euo pipefail

SEED_FILE="${1:-../../terraform/live/main/artifact_registry_seed_observability_images.txt}"

if [[ ! -f "$SEED_FILE" ]]; then
  echo "Seed file not found: $SEED_FILE"
  exit 1
fi

while IFS='|' read -r SRC DST; do
  [[ -z "${SRC}" || -z "${DST}" ]] && continue
  echo "==> Pulling ${SRC}"
  docker pull "${SRC}"

  echo "==> Tagging ${SRC} -> ${DST}"
  docker tag "${SRC}" "${DST}"

  echo "==> Pushing ${DST}"
  docker push "${DST}"
done < "$SEED_FILE"
