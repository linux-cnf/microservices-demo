# Observability chart

This chart wraps `kube-prometheus-stack` and provisions Prometheus, Alertmanager,
Grafana, kube-state-metrics, node-exporter, and repository-managed Grafana
dashboards. Dashboards cover application traffic/SLOs, Argo Rollouts, Istio,
tracing, Kubernetes health/capacity/cost/security, and production AI operations.

Argo CD uses `values-dev.yaml` or `values-prod.yaml` on top of `values.yaml`.
The AI dashboard is present in both renders, but its data is meaningful only
when the production-only AI platform is deployed and scraped.

## Validate locally

```bash
helm dependency build helm-chart/observability
helm lint helm-chart/observability \
  -f helm-chart/observability/values-dev.yaml
helm template observability helm-chart/observability \
  --namespace monitoring \
  -f helm-chart/observability/values-dev.yaml >/tmp/observability-dev.yaml
```

Use `values-prod.yaml` for a production render. Normal deployment is owned by
the environment's Argo CD `observability` Application.
