# AI Platform Demo Scenarios

## Overview

This document provides structured demonstrations that showcase the AI Platform Engineering implementation from infrastructure provisioning to production operations.

The demos are designed for technical interviews, architecture reviews, and platform demonstrations.

---

# Demo 1 — Platform Architecture Overview

## Objective

Introduce the overall platform architecture.

## Demonstration

Explain:

- Terraform provisions infrastructure.
- GitHub Actions automates CI/CD.
- Argo CD continuously reconciles Kubernetes.
- AI services run in a dedicated AI namespace.
- Istio secures service-to-service communication.
- Prometheus, Elasticsearch, and Tempo provide observability.

Highlight the separation between:

- Infrastructure
- Platform
- AI services
- Application workloads

---

# Demo 2 — AI Infrastructure Provisioning

## Objective

Demonstrate Infrastructure as Code.

Show:

```bash
terraform/live/main
```

Explain:

- AI node pool
- IAM
- Labels
- Taints
- Autoscaling

Verify:

```bash
kubectl get nodes --show-labels | grep workload=ai
```

---

# Demo 3 — GitOps Deployment

## Objective

Show GitOps deployment.

Explain:

Developer

↓

Git Commit

↓

GitHub Actions

↓

Git Repository

↓

Argo CD

↓

Kubernetes

Show:

```bash
kubectl get applications -n argocd
```

Explain:

- Sync
- Health
- Self-healing
- Drift detection

---

# Demo 4 — AI Platform

Show:

```bash
kubectl get pods -n ai
```

Explain each workload:

- ai-ollama
- ai-llm-gateway
- ai-agent-orchestrator
- ai-rate-limit-redis

---

# Demo 5 — LLM Gateway

Port forward:

```bash
kubectl port-forward svc/ai-llm-gateway 8080:8080 -n ai
```

Request:

```bash
curl -X POST http://localhost:8080/chat \
-H "Content-Type: application/json" \
-d '{"prompt":"hello"}'
```

Explain:

- REST API
- Model abstraction
- Runtime isolation

---

# Demo 6 — AI Agent

Port forward:

```bash
kubectl port-forward svc/ai-agent-orchestrator 8081:8080 -n ai
```

Ask:

```bash
curl -X POST http://localhost:8081/agent/chat \
-H "Content-Type: application/json" \
-d '{"prompt":"check AI platform health"}'
```

Explain:

- Tool orchestration
- Context gathering
- Prompt enrichment
- LLM interaction

---

# Demo 7 — Observability

Show:

- Prometheus metrics
- Grafana dashboard
- Elasticsearch logs
- Tempo traces

Explain how each contributes to platform monitoring and incident response.

---

# Demo 8 — Istio Security

Explain:

- mTLS
- AuthorizationPolicy
- PeerAuthentication
- NetworkPolicy

Show examples from the repository and describe how traffic is restricted between workloads.

---

# Demo 9 — Progressive Delivery

Show:

```bash
kubectl argo rollouts get rollout ai-llm-gateway -n ai
```

Explain:

- Canary deployment
- Traffic shifting
- AnalysisTemplate
- Prometheus validation
- Automatic rollback

---

# Demo 10 — Cost Optimization

Describe how the AI node pool can be enabled or disabled independently of the core platform.

Benefits:

- Reduced infrastructure cost
- Independent AI lifecycle
- Efficient resource utilization

---

# Demo 11 — End-to-End Request Flow

Walk through a complete request:

1. User submits a question in the AI Assistant.
2. AI Agent evaluates whether platform tools are needed.
3. Prometheus, Kubernetes API, or Elasticsearch are queried when appropriate.
4. Context is sent to the LLM Gateway.
5. LLM Gateway forwards the prompt to Ollama.
6. Response returns to the user.

Emphasize that the AI is augmented with live operational context rather than relying solely on the language model.

---

# Demo 12 — Interview Wrap-up

Summarize the technologies demonstrated:

- Terraform
- Kubernetes
- GitHub Actions
- Argo CD
- Kustomize
- Ollama
- LLM Gateway
- AI Agent Orchestrator
- Istio
- Prometheus
- Grafana
- Elasticsearch
- Tempo
- Argo Rollouts

Conclude by explaining how these technologies work together to form a production-ready AI Platform Engineering solution.
