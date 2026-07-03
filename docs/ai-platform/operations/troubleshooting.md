# AI Platform Troubleshooting Guide

## Overview

This guide documents common operational issues that may occur in the AI platform and the recommended investigation and recovery procedures.

---

# 1. AI Pods Not Starting

## Symptoms

- Pods remain in `Pending`
- Pods stay in `ContainerCreating`
- Pods enter `CrashLoopBackOff`

## Investigation

```bash
kubectl get pods -n ai

kubectl describe pod <pod-name> -n ai

kubectl get events -n ai --sort-by=.lastTimestamp
```

## Possible Causes

- AI node pool unavailable
- Insufficient resources
- Image pull failure
- Missing secrets
- PVC mount issues

## Resolution

- Verify AI node pool
- Check scheduling events
- Verify Artifact Registry access
- Confirm External Secrets synchronization
- Restart workload if necessary

---

# 2. AI Node Pool Scheduling Failure

## Symptoms

Pods remain Pending.

## Investigation

```bash
kubectl describe pod <pod-name>

kubectl get nodes --show-labels
```

Verify:

- workload=ai
- taints
- tolerations

## Resolution

- Enable AI node pool
- Verify Terraform provisioning
- Confirm tolerations match node taints

---

# 3. LLM Gateway Not Responding

## Investigation

```bash
kubectl logs deployment/ai-llm-gateway -n ai

kubectl get svc -n ai
```

Verify:

```bash
curl http://localhost:8080/healthz
```

## Resolution

- Restart deployment
- Verify Ollama connectivity
- Check service endpoints

---

# 4. AI Agent Cannot Answer Platform Questions

## Symptoms

Responses do not include live cluster information.

## Investigation

- Check Prometheus connectivity
- Verify Kubernetes RBAC
- Verify Elasticsearch connectivity
- Review AI Agent logs

```bash
kubectl logs deployment/ai-agent-orchestrator -n ai
```

## Resolution

- Verify environment variables
- Confirm ServiceAccounts
- Validate RBAC permissions
- Test each tool independently

---

# 5. Prometheus Metrics Missing

## Investigation

```bash
kubectl get servicemonitor -A

kubectl get prometheusrule -A
```

Verify:

```bash
curl http://localhost:8080/metrics
```

## Resolution

- Confirm ServiceMonitor labels
- Verify Prometheus target discovery
- Restart Prometheus if required

---

# 6. Argo CD OutOfSync

## Investigation

```bash
argocd app get ai-platform
```

## Resolution

```bash
argocd app sync ai-platform
```

If drift persists:

- Compare live manifests
- Review ignoreDifferences rules
- Check Kustomize output

---

# 7. Canary Rollout Fails

## Investigation

```bash
kubectl argo rollouts get rollout ai-llm-gateway -n ai
```

Check:

- AnalysisTemplate
- Prometheus metrics
- Rollout events

## Resolution

- Fix failing metric
- Retry rollout
- Roll back if required

---

# 8. Istio Communication Failure

## Symptoms

503 responses or connection failures.

## Investigation

```bash
kubectl get peerauthentication -A

kubectl get authorizationpolicy -A

kubectl get virtualservice -A

kubectl get destinationrule -A
```

## Resolution

- Verify mTLS configuration
- Check AuthorizationPolicy rules
- Validate VirtualService routing

---

# 9. Elasticsearch Log Queries Return No Results

## Investigation

- Verify Elasticsearch health
- Confirm index exists
- Check AI Agent configuration

## Resolution

- Verify credentials
- Validate CA certificate
- Confirm log ingestion pipeline

---

# 10. Tempo Traces Missing

## Investigation

- Verify OpenTelemetry Collector
- Check Tempo health
- Confirm trace export configuration

## Resolution

- Restart collector
- Validate OTLP endpoint
- Verify sampling configuration

---

# General Troubleshooting Workflow

1. Verify Argo CD health.
2. Confirm AI namespace status.
3. Inspect pod status.
4. Review Kubernetes events.
5. Check application logs.
6. Validate Prometheus metrics.
7. Review Elasticsearch logs.
8. Inspect Tempo traces.
9. Verify Istio configuration.
10. Roll back if necessary.

---

# Useful Commands

```bash
kubectl get pods -n ai

kubectl describe pod <pod>

kubectl logs deployment/ai-llm-gateway -n ai

kubectl logs deployment/ai-agent-orchestrator -n ai

kubectl get events -n ai

kubectl argo rollouts get rollout ai-llm-gateway -n ai

argocd app get ai-platform
```

---

# Summary

A structured troubleshooting approach—starting with cluster health, then workloads, logs, metrics, traces, networking, and finally GitOps state—helps identify issues quickly while minimizing service disruption.
