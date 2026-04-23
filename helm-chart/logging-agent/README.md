# logging-agent

## Overview
Deploys **Elastic Agent (DaemonSet)** to collect logs from all Kubernetes nodes and send them to Elasticsearch.

---

## Components & Use Cases

- **Elastic Agent**
  - Collect pod + node logs
  - Forward logs to Elasticsearch

- **RBAC (ServiceAccount + Role)**
  - Access Kubernetes metadata

- **DaemonSet**
  - Ensures agent runs on every node

---

## Installation

```bash
helm upgrade --install logging-agent ./helm-chart/logging-agent \
  -n logging --create-namespace


Preview
helm template logging-agent ./helm-chart/logging-agent -n logging

Workflow Pattern
Update values/templates
Validate:
helm lint ./helm-chart/logging-agent
Create PR → CI validates
Merge → Deploy via Argo CD / pipeline

Production Notes
Runs on all nodes (auto-scales with cluster)
Keep CPU/memory limits minimal
Requires Elasticsearch (logging chart)
Used only for log collection (not storage)
