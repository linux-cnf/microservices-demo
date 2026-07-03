# AI Platform Deployment Guide

## Purpose

This guide explains how to deploy the AI platform on top of the existing Kubernetes microservices platform.

---

# Prerequisites

Before deploying the AI platform, ensure the following components are already available:

- GKE cluster is provisioned
- Terraform backend is configured
- Argo CD is installed and healthy
- GitHub Actions secrets are configured
- Artifact Registry repositories exist
- External Secrets Operator is running
- Google Secret Manager integration is working
- Prometheus, Grafana, Elasticsearch, and Tempo are deployed
- Istio service mesh is installed

---

# Deployment Architecture

```text
Terraform
        │
        ▼
Provision AI Node Pool
        │
        ▼
GitHub Actions Bootstrap Workflow
        │
        ▼
scripts/ai-cluster-bootstrap.sh
        │
        ▼
Argo CD
        │
        ▼
Kustomize
        │
        ▼
Deploy AI Platform
 ├── ai-ollama
 ├── ai-llm-gateway
 ├── ai-agent-orchestrator
 ├── ai-rate-limit-redis
 ├── Prometheus integration
 ├── Kubernetes API integration
 ├── Elasticsearch integration
 └── Istio security
```

---

# Step 1 — Enable AI Infrastructure

Run the AI Platform Bootstrap workflow.

Terraform creates:

- Dedicated AI node pool
- AI service account
- IAM permissions
- Node labels
- Node taints

Verify:

```bash
kubectl get nodes --show-labels | grep workload=ai
```

Expected output should contain:

- workload=ai
- purpose=llm
- tier=platform

---

# Step 2 — Register AI Platform

Enable the AI platform.

```bash
./scripts/ai-cluster-bootstrap.sh enable-assistant
```

Expected output:

- AI Assistant enabled
- LLM Gateway ready
- Frontend rollout healthy

Verify:

```bash
kubectl get applications -n argocd | grep ai-platform
```

Expected:

```
ai-platform    Synced    Healthy
```

---

# Step 3 — Verify AI Namespace

```bash
kubectl get ns ai
```

Expected:

```
STATUS: Active
```

Verify workloads:

```bash
kubectl get pods -n ai
```

Expected components:

- ai-ollama
- ai-llm-gateway
- ai-agent-orchestrator
- ai-rate-limit-redis

Verify services:

```bash
kubectl get svc -n ai
```

Expected:

- ai-ollama
- ai-llm-gateway
- ai-agent-orchestrator
- ai-rate-limit-redis

---

# Step 4 — Verify LLM Gateway

Port forward:

```bash
kubectl port-forward -n ai svc/ai-llm-gateway 8080:8080
```

Test:

```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"hello"}'
```

Expected response:

```json
{
  "model": "tinyllama",
  "response": "..."
}
```

---

# Step 5 — Verify AI Agent Orchestrator

Port forward:

```bash
kubectl port-forward -n ai svc/ai-agent-orchestrator 8081:8080
```

Test:

```bash
curl -X POST http://localhost:8081/agent/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"check AI platform health"}'
```

Expected response:

```json
{
  "model": "ai-agent-orchestrator",
  "response": "...",
  "tool_used": "...",
  "tool_result": {}
}
```

---

# Canary Deployment

The LLM Gateway supports two deployment strategies.

### Standard Deployment

- Kubernetes Deployment
- Immediate rollout
- Simple upgrade

### Progressive Delivery

Using Argo Rollouts:

- Canary deployment
- Progressive traffic shifting
- Automated AnalysisTemplate
- Prometheus validation
- Automatic rollback
- Zero-downtime upgrades

---

# Observability

Monitor AI services using:

- Prometheus metrics
- Grafana dashboards
- Elasticsearch logs
- Tempo traces
- Kubernetes Events

Health endpoints:

```text
GET /healthz
GET /readyz
GET /metrics
```

Available on:

- ai-llm-gateway
- ai-agent-orchestrator

---

# Security

The AI platform is protected using:

- Istio mTLS
- AuthorizationPolicy
- PeerAuthentication
- NetworkPolicy
- Dedicated AI node pool
- Kubernetes RBAC
- Service Accounts
- External Secrets

---

# GitOps Workflow

Infrastructure changes

↓

Terraform

↓

GitHub Actions

↓

Git Repository

↓

Argo CD

↓

Kubernetes

↓

AI Platform

Every deployment is fully declarative.

---

# Cost Control

The AI infrastructure is optional.

When AI workloads are not needed:

- Disable AI node pool
- Remove expensive compute
- Keep the rest of the platform running

This significantly reduces infrastructure cost while preserving the core application.

---

# Verified Runtime

The following deployment has been successfully validated.

✅ AI node pool created

✅ Argo CD application Healthy

✅ AI namespace Active

✅ AI workloads Running

✅ LLM Gateway responding

✅ AI Agent Orchestrator responding

✅ Frontend AI Assistant enabled

✅ Canary rollout supported

---

# Deployment Summary

The AI platform provides a production-ready deployment model that combines:

- Terraform Infrastructure as Code
- Kubernetes
- GitHub Actions CI/CD
- Argo CD GitOps
- Ollama (vLLM-ready architecture)
- AI LLM Gateway
- AI Agent Orchestrator
- Prometheus
- Grafana
- Elasticsearch
- Tempo
- Istio Service Mesh
- Argo Rollouts
- External Secrets
- Cost-controlled AI infrastructure

This deployment process reflects a production-grade AI Platform Engineering workflow suitable for enterprise environments.
