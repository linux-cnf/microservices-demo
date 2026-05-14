#!/usr/bin/env bash
set -euo pipefail

SEED_FILE="${1:-../../terraform/live/main/artifact_registry_seed_platform_images.txt}"
SKIPPED=0
PUSHED=0

if [[ ! -f "$SEED_FILE" ]]; then
  echo "Seed file not found: $SEED_FILE"
  exit 1
fi

while IFS='|' read -r SRC DST; do
  [[ -z "${SRC}" || -z "${DST}" ]] && continue

  echo "==> Checking ${DST}"
  if docker manifest inspect "${DST}" >/dev/null 2>&1; then
    echo "==> SKIP: already exists"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "==> Pulling ${SRC}"
  docker pull "${SRC}"

  echo "==> Tagging ${SRC} -> ${DST}"
  docker tag "${SRC}" "${DST}"

  echo "==> Pushing ${DST}"
  docker push "${DST}"
  PUSHED=$((PUSHED + 1))
done < "$SEED_FILE"

echo "Done. Pushed=${PUSHED}, Skipped=${SKIPPED}"
