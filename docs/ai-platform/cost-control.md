# AI Platform Cost Control

## Overview

Running AI workloads continuously can significantly increase infrastructure costs. This platform was designed to support on-demand AI infrastructure, allowing expensive resources to be enabled only when required.

---

# Design Goals

The cost optimization strategy aims to:

- Minimize idle infrastructure costs
- Keep the core platform running independently of AI workloads
- Provision AI resources only when needed
- Maintain a fully reproducible environment through Infrastructure as Code

---

# Dedicated AI Node Pool

AI services run on a dedicated Kubernetes node pool.

Benefits include:

- Isolation from application workloads
- Independent scaling
- Easier maintenance
- Controlled operational costs

Node characteristics:

- Label: `workload=ai`
- Taint: `workload=ai:NoSchedule`
- Autoscaling enabled

---

# On-Demand AI Infrastructure

The AI node pool is not required for the core microservices platform.

Typical workflow:

1. Enable AI node pool with Terraform.
2. Deploy AI services through Argo CD.
3. Use the AI platform for development, testing, or demonstrations.
4. Disable the AI node pool when no longer required.

This approach allows the platform to reduce compute costs while preserving the GitOps-managed application state.

---

# GitOps-Based Deployment

AI workloads are deployed declaratively through Argo CD.

Advantages:

- Deploy only when required
- Automatic reconciliation
- No manual configuration drift
- Repeatable deployments

---

# AI Runtime Optimization

The platform currently uses Ollama with a lightweight model.

Advantages:

- Local inference
- Lower operational cost
- Simple deployment
- Easy replacement with future runtimes such as vLLM

---

# Infrastructure Separation

The platform separates:

- Core application infrastructure
- AI infrastructure

This allows independent lifecycle management and prevents AI resources from consuming capacity needed by application services.

---

# Operational Best Practices

- Enable AI resources only for active use.
- Keep AI workloads isolated from production traffic.
- Monitor utilization through Prometheus and Grafana.
- Scale AI services according to demand.
- Review infrastructure usage regularly.

---

# Summary

The AI platform balances functionality and operational cost by combining Infrastructure as Code, GitOps, dedicated AI resources, and on-demand provisioning. This design allows organizations to experiment with AI capabilities without permanently increasing infrastructure expenditure.
