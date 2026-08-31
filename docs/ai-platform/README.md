# AI platform engineering documentation

The optional AI platform adds an Ollama inference runtime, LLM gateway, agent
orchestrator, Redis rate limiting, frontend assistant integration, observability,
Istio policy, and an optional Argo Rollouts canary to Online Boutique.

> **Environment support:** the end-to-end AI bootstrap and GitOps path is
> currently production-only. The AI workflows accept only `prod`, the optional
> Argo CD Application tracks `main`, and AI resources are not part of the dev
> root app. A dev Terraform node-pool definition exists, but it is not a
> supported complete dev AI deployment workflow.

## Implementation

| Layer | Repository source |
| --- | --- |
| Infrastructure | `terraform/live/prod/ai-node-pool.tf` and `ai-iam.tf` |
| Runtime and services | `kustomize/ai-platform/base` |
| CPU/model profiles | `kustomize/ai-platform/models/cpu-small` and `cpu-better` |
| Security | `kustomize/ai-platform/security` |
| Canary delivery | `kustomize/ai-platform/rollout` |
| GitOps entrypoint | `argocd/optional-apps/ai-platform/manifests/ai-platform.yaml` |
| Automation | `.github/workflows/ai-platform-bootstrap.yml`, `ai-nodepool-disable.yml`, and `ai-platform-ci.yml` |

The base includes namespaces, RBAC, a persistent model cache, Ollama and model
bootstrap, the gateway and orchestrator, rate-limit Redis, ServiceMonitors,
Prometheus rules, a Grafana dashboard ConfigMap, and the security layer. The
rollout overlay removes the normal gateway Deployment and substitutes a Rollout
and Prometheus AnalysisTemplate.

## Request flow

```text
Frontend assistant
        |
        v
AI agent orchestrator ----> Kubernetes API / Prometheus / Elasticsearch
        |
        v
LLM gateway ----> rate-limit Redis
        |
        v
Ollama model runtime
```

## Documentation map

- [Architecture](architecture.md)
- [Components](components.md)
- [System design](system-design.md)
- [Workflow](workflow.md)
- [Deployment guide](deployment-guide.md)
- [Cost control](cost-control.md)
- [AI observability](phase10-ai-observability.md)
- [Operations runbook](operations/runbook.md)
- [Troubleshooting](operations/troubleshooting.md)
- [Disaster recovery](operations/disaster-recovery.md)
- [Demo scenarios](demo/demo-scenarios.md)
- [Lessons learned](lessons-learned.md)
- [Project showcase](project-showcase.md)

## Safe local validation

Rendering does not connect to a cluster:

```bash
kubectl kustomize kustomize/ai-platform/models/cpu-small >/tmp/ai-small.yaml
kubectl kustomize kustomize/ai-platform/models/cpu-better >/tmp/ai-better.yaml
kubectl kustomize kustomize/ai-platform/rollout >/tmp/ai-rollout.yaml
```

Deploy only through the documented production bootstrap after reviewing GCP
costs, node-pool capacity, required secrets, and workflow approvals.
