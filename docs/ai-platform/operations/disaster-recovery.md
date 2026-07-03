# AI Platform Disaster Recovery

## Overview

This document describes how the AI Platform can be recovered after failures affecting workloads, the Kubernetes cluster, or cloud infrastructure.

---

# Recovery Objectives

| Objective | Target |
|-----------|--------|
| Configuration Recovery | GitOps |
| Infrastructure Recovery | Terraform |
| Application Recovery | Argo CD |
| Data Recovery | Persistent Volumes & Secret Manager |

---

# Failure Scenarios

## Scenario 1 – AI Pod Failure

Recovery:

```bash
kubectl get pods -n ai

kubectl rollout restart deployment ai-llm-gateway -n ai
```

Expected:

- Kubernetes recreates the pod.
- Service remains available.

---

## Scenario 2 – AI Node Failure

Recovery:

- Kubernetes reschedules workloads.
- Cluster Autoscaler provisions replacement capacity if required.

Verify:

```bash
kubectl get nodes
kubectl get pods -n ai -o wide
```

---

## Scenario 3 – Argo CD Drift

Recovery:

```bash
argocd app sync ai-platform
```

Verify:

```bash
argocd app get ai-platform
```

---

## Scenario 4 – Accidental Resource Deletion

Recovery:

Deleted Kubernetes resources are automatically recreated by Argo CD because Git remains the source of truth.

---

## Scenario 5 – AI Node Pool Deleted

Recovery:

Re-run the Terraform deployment.

```bash
terraform apply
```

Verify:

```bash
kubectl get nodes --show-labels | grep workload=ai
```

---

## Scenario 6 – Entire Cluster Lost

Recovery sequence:

1. Provision infrastructure using Terraform.
2. Install Argo CD.
3. Bootstrap the platform.
4. Register the AI platform application.
5. Argo CD restores workloads from Git.
6. Validate AI services.

---

# Backup Strategy

Critical assets:

- Git repository
- Terraform state
- Secret Manager secrets
- Persistent AI model cache (if required)

---

# Recovery Validation

After recovery, verify:

```bash
kubectl get applications -n argocd

kubectl get pods -n ai

kubectl get svc -n ai

kubectl argo rollouts get rollout ai-llm-gateway -n ai
```

Ensure:

- Argo CD: Synced / Healthy
- AI workloads: Running
- Services: Reachable
- Rollouts: Healthy

---

# Summary

The platform is designed so that Git, Terraform, and Argo CD together provide reproducible recovery. Infrastructure can be recreated from code, applications are restored declaratively, and Kubernetes handles workload rescheduling automatically.
