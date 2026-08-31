# Logging Agent chart

This chart deploys Elastic Agent as a DaemonSet, its service account/RBAC, and a
Kibana dashboard import job. The agent enriches and forwards node/workload logs
to the Elasticsearch service deployed by `helm-chart/logging`.

Environment values are under `env/dev/values.yaml` and `env/prod/values.yaml`.
The logging backend and required secrets must be ready before the agent starts.

## Validate locally

```bash
helm lint helm-chart/logging-agent \
  -f helm-chart/logging-agent/env/dev/values.yaml
helm template logging-agent helm-chart/logging-agent \
  --namespace logging \
  -f helm-chart/logging-agent/env/dev/values.yaml >/tmp/logging-agent.yaml
```

Normal deployment is owned by the environment-specific Argo CD `logging-agent`
Application.
