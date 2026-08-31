# Logging chart

This chart declares the ECK dependency and repository-managed Elasticsearch and
Kibana resources. It provides the storage and search backend consumed by the
`logging-agent` chart.

## Validate locally

```bash
helm dependency build helm-chart/logging
helm lint helm-chart/logging
helm template logging helm-chart/logging \
  --namespace logging >/tmp/logging.yaml
```

Normal deployment is owned by the environment-specific Argo CD `logging`
Application. Monitor persistent-volume capacity and Elasticsearch health; define
retention, backup, and recovery requirements before using the lab configuration
for important data.
