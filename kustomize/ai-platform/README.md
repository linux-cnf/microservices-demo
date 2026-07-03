# AI Platform

This directory contains the complete GitOps deployment for the AI platform using Kustomize and Argo CD.

## Directory Structure

```text
ai-platform/
├── base/       # Core AI platform resources
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
rollout/
    │
    ▼
base/
    │
    ├── AI workloads
    ├── Observability
    └── security/
```

## Argo CD Sync Waves

| Wave | Resources |
|------:|-----------|
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
