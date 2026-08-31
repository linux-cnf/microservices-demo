# AI Platform

This directory contains the complete GitOps deployment for the AI platform using Kustomize and Argo CD.

The supported end-to-end deployment is currently production-only. The optional
Argo CD Application tracks `main`, and the AI bootstrap/disable workflows expose
only `prod`.

## Directory Structure

```text
ai-platform/
├── base/       # Core AI platform resources
├── models/     # cpu-small and cpu-better resource/model profiles
├── security/   # Istio mTLS, AuthorizationPolicies, NetworkPolicies
└── rollout/    # Argo Rollouts canary deployment for AI LLM Gateway
```

## Components

- AI Ollama runtime
- AI LLM Gateway
- AI Agent Orchestrator
- AI Rate Limit Redis
- Observability (ServiceMonitor, PrometheusRule, Grafana Dashboard)
- Istio security policies
- Argo Rollouts and AnalysisTemplate

## Deployment Flow

```text
Argo CD
    │
    ▼
base/ (normal) or rollout/ (canary)
    │
    ▼
base/
    │
    ├── AI workloads
    ├── Observability
    └── security/
```

Render a profile explicitly; the bootstrap workflow selects one of these model
overlays before applying the optional Argo CD Application:

```bash
kubectl kustomize kustomize/ai-platform/models/cpu-small >/tmp/ai-cpu-small.yaml
kubectl kustomize kustomize/ai-platform/models/cpu-better >/tmp/ai-cpu-better.yaml
kubectl kustomize kustomize/ai-platform/rollout >/tmp/ai-canary.yaml
```

## Argo CD Sync Waves

| Wave | Resources |
| ---: | --- |
| -5 | Namespaces |
| -4 | ServiceAccounts & RBAC |
| -3 | PersistentVolumeClaims |
| -2 | Services |
| -1 | Core infrastructure (Ollama, Redis) |
| 0 | AI workloads (Deployments, Rollouts, AnalysisTemplates) |
| 1 | Security resources |
| 2 | Observability resources |
| PostSync | Ollama model bootstrap job |

## Design Goals

- Fully declarative GitOps deployment
- Automatic drift detection and self-healing
- Progressive delivery with Argo Rollouts
- Secure service-to-service communication using Istio mTLS
- Built-in observability and monitoring
- Production-ready deployment ordering using Argo CD Sync Waves
