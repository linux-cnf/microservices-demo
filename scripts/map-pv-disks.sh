#!/usr/bin/env bash
set -euo pipefail

echo "PV | CLAIM | STORAGECLASS | CAPACITY | DISK"
kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" | "}{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{" | "}{.spec.storageClassName}{" | "}{.spec.capacity.storage}{" | "}{.spec.csi.volumeHandle}{"\n"}{end}'
