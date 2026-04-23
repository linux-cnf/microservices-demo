# logging

## Overview
Provides **log storage and visualization** using:

- Elasticsearch  
- Kibana (via ECK)

---

## Components & Use Cases

- **Elasticsearch**
  - Store and index logs
  - Fast search and retention

- **Kibana**
  - UI for log exploration and debugging

- **Persistent Storage**
  - Ensures logs are not lost on restart

---

## Installation

```bash
helm dependency update ./helm-chart/logging

helm upgrade --install logging ./helm-chart/logging \
  -n logging --create-namespace

Preview
helm template logging ./helm-chart/logging -n logging

Workflow Pattern
Update values.yaml
Validate:
helm lint
helm dependency update
Create PR → CI validates
Merge → Deploy via Argo CD / pipeline

Production Notes
Use dedicated observability node pool
Monitor disk usage (very important)
Enable backups for Elasticsearch
Scale using storage or nodeSets
Works with logging-agent for log ingestion
