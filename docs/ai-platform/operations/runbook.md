# AI Platform Operations Runbook

## Purpose

This runbook provides the standard operating procedures for managing the AI Platform in production. It covers routine operational tasks, health verification, deployment validation, monitoring, and recovery procedures.

---

# Daily Health Checks

## Verify Argo CD

```bash
kubectl get applications -n argocd
```

Expected:

- All applications are **Synced**
- All applications are **Healthy**

---

## Verify AI Namespace

```bash
kubectl get ns ai
```

Expected:

```
STATUS: Active
```

---

## Verify AI Workloads

```bash
kubectl get pods -n ai
```

Expected workloads:

- ai-ollama
- ai-llm-gateway
- ai-agent-orchestrator
- ai-rate-limit-redis

All pods should be:

- Running
- Ready
- No restart loops

---

## Verify Services

```bash
kubectl get svc -n ai
```

Expected services:

- ai-ollama
- ai-llm-gateway
- ai-agent-orchestrator
- ai-rate-limit-redis

---

# Verify Health Endpoints

## LLM Gateway

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```

---

## AI Agent

```bash
curl http://localhost:8081/healthz
curl http://localhost:8081/readyz
```

---

# Verify AI Requests

LLM Gateway:

```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"hello"}'
```

AI Agent:

```bash
curl -X POST http://localhost:8081/agent/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"check AI platform health"}'
```

---

# Verify Canary Rollout

```bash
kubectl argo rollouts get rollout ai-llm-gateway -n ai
```

Expected:

- Healthy
- Stable
- No paused rollout
- No degraded analysis

---

# Verify Observability

## Metrics

```bash
curl http://localhost:8080/metrics
curl http://localhost:8081/metrics
```

---

## Prometheus Targets

Confirm AI workloads are scraped successfully.

---

## Grafana Dashboard

Verify:

- Request rate
- Error rate
- Latency
- AI metrics

---

## Elasticsearch

Confirm logs are being ingested.

---

## Tempo

Verify traces are available for AI requests.

---

# Verify AI Node Pool

```bash
kubectl get nodes --show-labels | grep workload=ai
```

Confirm:

- workload=ai
- purpose=llm
- tier=platform

---

# Scaling

Scale the LLM Gateway:

```bash
kubectl scale deployment ai-llm-gateway \
  --replicas=3 \
  -n ai
```

Verify:

```bash
kubectl get pods -n ai
```

---

# Rolling Restart

Restart AI services safely:

```bash
kubectl rollout restart deployment ai-llm-gateway -n ai

kubectl rollout restart deployment ai-agent-orchestrator -n ai
```

---

# GitOps Operations

Force Argo CD reconciliation:

```bash
argocd app sync ai-platform
```

Check application health:

```bash
argocd app get ai-platform
```

---

# Cost Optimization

Disable AI infrastructure when idle.

Expected outcome:

- AI node pool removed
- Core platform remains operational
- Infrastructure cost reduced

---

# Log Collection

View AI logs:

```bash
kubectl logs deployment/ai-llm-gateway -n ai

kubectl logs deployment/ai-agent-orchestrator -n ai

kubectl logs deployment/ai-ollama -n ai
```

---

# Incident Response Checklist

When an incident occurs:

1. Verify Argo CD health
2. Verify AI namespace
3. Check pod status
4. Review Kubernetes events
5. Review Prometheus metrics
6. Review Elasticsearch logs
7. Review Tempo traces
8. Verify Istio traffic
9. Check recent deployments
10. Roll back if required

---

# Recovery Strategy

Recover services in this order:

1. Infrastructure
2. Argo CD
3. AI Runtime
4. LLM Gateway
5. AI Agent
6. Frontend AI Assistant

---

# Operational Best Practices

- Use GitOps for all configuration changes.
- Avoid manual modifications in the cluster.
- Monitor AI metrics continuously.
- Investigate restart loops immediately.
- Validate canary deployments before promotion.
- Keep AI workloads isolated on the dedicated AI node pool.
- Rotate secrets through External Secrets and Secret Manager.
- Review logs and traces during incident investigations.

---

# Summary

Following this runbook helps ensure the AI platform remains healthy, secure, observable, and recoverable while adhering to GitOps and production operational best practices.
