# AI Platform Architecture

## Overview

The AI Platform extends the Online Boutique microservices application into a production-ready AI Platform Engineering environment. The architecture combines Infrastructure as Code (IaC), GitOps, Kubernetes, AI inference, observability, security, and progressive delivery to demonstrate how AI workloads can be operated reliably in production.

The platform is designed around cloud-native principles:

- Kubernetes-native deployments
- GitOps-driven reconciliation
- Infrastructure managed with Terraform
- Service mesh security using Istio
- AI observability through Prometheus, Grafana, Elasticsearch, and Tempo
- Progressive delivery with Argo Rollouts
- Cost-optimized AI infrastructure using a dedicated AI node pool

---

# High-Level Architecture

```text
                    Developers
                         │
                         ▼
                  GitHub Repository
                         │
             GitHub Actions CI/CD
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
 Terraform Infrastructure          Container Images
        │                                 │
        ▼                                 ▼
 Dedicated AI Node Pool          Artifact Registry
                 \               /
                  \             /
                   ▼           ▼
                     Argo CD GitOps
                           │
                           ▼
                  Kubernetes Cluster
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   AI Runtime         LLM Gateway     AI Agent Orchestrator
    (Ollama)                │                  │
                             └──────────┬──────┘
                                        │
                    ┌───────────────────┼────────────────────┐
                    ▼                   ▼                    ▼
              Prometheus         Kubernetes API      Elasticsearch
                    │                                      │
                    ▼                                      ▼
                 Grafana                               Platform Logs
                                        │
                                        ▼
                                      Tempo
```

---

# Core Components

The AI platform consists of four primary workloads deployed in the `ai` namespace:

- ai-ollama
- ai-llm-gateway
- ai-agent-orchestrator
- ai-rate-limit-redis

These workloads are deployed declaratively through Argo CD and managed using Kustomize overlays.

---

# Request Flow

A typical AI request follows this sequence:

1. User opens the AI Assistant in the frontend.
2. The frontend sends the request to the AI Agent Orchestrator.
3. The AI Agent determines whether platform tools are required.
4. If needed, it queries:
   - Prometheus for metrics
   - Kubernetes API for cluster state
   - Elasticsearch for logs
5. The collected context is forwarded to the LLM Gateway.
6. The LLM Gateway sends the prompt to Ollama.
7. The generated response is returned through the gateway to the frontend.

This tool-assisted workflow allows the AI to answer questions using live platform context rather than relying solely on the language model.

---

# Infrastructure Architecture

Infrastructure provisioning is managed entirely through Terraform.

Resources include:

- GKE cluster
- Dedicated AI node pool
- IAM service accounts
- Artifact Registry
- Secret Manager integration
- Networking
- Autoscaling configuration

The AI node pool is isolated using labels and taints to ensure AI workloads do not compete with application workloads.

---

# GitOps Architecture

Application deployment is managed through Argo CD.

The workflow is:

```text
Developer
    │
    ▼
Git Commit
    │
    ▼
GitHub Actions
    │
    ▼
Update Git Manifests
    │
    ▼
Argo CD
    │
    ▼
Kubernetes
```

Argo CD continuously reconciles the cluster to the desired state stored in Git, providing automated synchronization, self-healing, and drift correction.

---

# Security Architecture

The platform adopts a defense-in-depth approach.

Security mechanisms include:

- Istio mTLS
- AuthorizationPolicy
- PeerAuthentication
- Kubernetes RBAC
- Dedicated service accounts
- NetworkPolicy
- External Secrets
- Google Secret Manager integration

These controls ensure secure service-to-service communication and centralized secret management.

---

# Observability Architecture

The platform exposes operational telemetry through multiple layers.

Metrics:

- Prometheus
- ServiceMonitor
- PrometheusRule

Visualization:

- Grafana dashboards

Logs:

- Elasticsearch

Tracing:

- Tempo

Health endpoints:

- `/healthz`
- `/readyz`
- `/metrics`

This observability stack enables proactive monitoring, troubleshooting, and automated rollback decisions.

---

# Progressive Delivery

The AI LLM Gateway supports two deployment strategies:

- Standard Kubernetes Deployment
- Argo Rollouts Canary Deployment

The canary workflow integrates with Prometheus AnalysisTemplates to validate health before promoting new versions.

Benefits include:

- Zero-downtime deployments
- Automated validation
- Automatic rollback
- Reduced deployment risk

---

# Cost Optimization

AI workloads run on a dedicated AI node pool that can be enabled or disabled independently from the core platform.

This architecture enables:

- Lower infrastructure cost
- Independent AI lifecycle management
- On-demand AI capacity
- Reduced idle GPU/CPU usage

---

# Future Enhancements

The platform has been designed to support future enhancements with minimal architectural changes.

Potential improvements include:

- vLLM runtime
- GPU-enabled node pools
- Multi-model routing
- RAG (Retrieval-Augmented Generation)
- Vector databases
- Model registry integration
- Horizontal AI scaling
- Multi-cluster GitOps
- Multi-region disaster recovery

---

# Summary

This architecture demonstrates a production-grade AI Platform Engineering implementation that combines Kubernetes, Terraform, GitOps, Istio, observability, and AI services into a cohesive platform. It is intended to showcase modern cloud-native operational practices while remaining extensible for future AI capabilities.
