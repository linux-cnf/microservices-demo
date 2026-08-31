# Platform Helm charts

This directory contains charts consumed by the environment-specific Argo CD
Applications.

| Chart | Purpose |
| --- | --- |
| `observability` | kube-prometheus-stack plus repository-managed Grafana dashboards |
| `logging` | ECK dependency and Elasticsearch/Kibana resources |
| `logging-agent` | Elastic Agent, RBAC, and Kibana dashboard import |
| `tracing` | Tempo, OpenTelemetry Collector, and mesh tracing configuration |
| `kiali` | Kiali dependency and environment values |

Argo CD selects the matching dev or prod values. Logging Agent depends on the
logging backend, while dashboard data sources depend on observability and
tracing. Sync waves in `argocd/apps/dev` and `argocd/apps/prod` define the actual
installation order.

## Local validation

Build dependencies before linting charts that declare them:

```bash
for chart in helm-chart/observability helm-chart/logging \
  helm-chart/tracing helm-chart/kiali; do
  helm dependency build "$chart"
done

helm lint helm-chart/observability -f helm-chart/observability/values-dev.yaml
helm template observability helm-chart/observability \
  --namespace monitoring -f helm-chart/observability/values-dev.yaml >/tmp/observability.yaml
```

Repeat with the chart's prod values where present. `helm-chart-ci.yaml` lints and
templates all five charts; `kubevious-manifests-ci.yaml` additionally analyzes
the logging charts.

Prefer changing values/templates through Git and allowing Argo CD to deploy
them. Direct `helm upgrade` commands create state outside the GitOps ownership
model and are intended only for isolated testing.
