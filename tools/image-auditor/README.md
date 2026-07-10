# Kubernetes Image Auditor

Scans Kubernetes Pods and reports container images that do not originate
from approved Google Artifact Registry repositories.

## Requirements

- Go
- kubectl
- Access to the Kubernetes cluster

## Build

make image-auditor-build

## Run

./scripts/run-image-auditor.sh

## Scan one namespace

./scripts/run-image-auditor.sh --namespace boutique

## JSON output

./scripts/run-image-auditor.sh --output json
