# observability

## Overview
Provides **metrics, dashboards, and alerting** using:

- Prometheus  
- Grafana  
- Alertmanager  

---

## Components & Use Cases

- **Prometheus**
  - Collect cluster and application metrics

- **Grafana**
  - Dashboards and visualization

- **Alertmanager**
  - Alert routing and notifications

- **kube-state-metrics**
  - Kubernetes object metrics

- **node-exporter**
  - Node-level CPU, memory, disk metrics

---

## Installation

```bash
helm dependency update ./helm-chart/observability

helm upgrade --install observability ./helm-chart/observability \
  -n monitoring --create-namespace

Preview
helm template observability ./helm-chart/observability -n monitoring

Workflow Pattern
Update values/templates
Validate:
helm lint
Create PR → CI validates
Merge → Deploy via Argo CD / pipeline

Production Notes
Use dedicated observability node pool
Monitor Golden Signals:
latency, traffic, errors, saturation
Enable alerting early
Keep Grafana secured (auth later)
Optional: enable Loki for logs integration
