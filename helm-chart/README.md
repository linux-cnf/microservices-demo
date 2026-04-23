# helm-chart

## Overview
This directory contains **platform Helm charts** for logging and observability.

Each chart is independent and follows a modular deployment approach.

---

## Charts

- **logging-agent**
  - Collects logs from Kubernetes nodes
  - Ships logs to Elasticsearch

- **logging**
  - Provides Elasticsearch + Kibana
  - Stores and visualizes logs

- **observability**
  - Provides Prometheus + Grafana + Alertmanager
  - Metrics, dashboards, and alerting

---

## Installation Order (Recommended)

1. observability  
2. logging  
3. logging-agent  

---

## Preview Charts

```bash
helm template <chart-name> ./helm-chart/<chart-name>
Example: helm template logging ./helm-chart/logging

Workflow Pattern
Update chart (values/templates)
Validate: helm lint ./helm-chart/<chart>
Create PR → CI validation
Merge → Deploy via Argo CD / pipeline

Production Notes
Use dedicated observability node pool
Keep charts independent and modular
Prefer GitOps (Argo CD) for deployments
Scale components based on workload
