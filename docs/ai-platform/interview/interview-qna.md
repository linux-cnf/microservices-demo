# AI Platform Interview Questions & Answers

## Overview

This document contains interview questions and reference answers based on the AI Platform Engineering implementation. The questions focus on architecture, Kubernetes, GitOps, observability, security, and production operations.

---

# 1. What problem does this AI platform solve?

### Answer

The platform demonstrates how AI workloads can be deployed and operated using cloud-native Platform Engineering principles. Rather than exposing a standalone LLM, it integrates AI with live operational data from Kubernetes, Prometheus, and Elasticsearch. The result is an AI assistant that can answer questions using the current state of the platform instead of relying only on pretrained knowledge.

---

# 2. Why did you introduce an LLM Gateway?

### Answer

The LLM Gateway separates clients from the underlying inference engine. Applications communicate with a stable API while the runtime can change independently—for example, from Ollama today to vLLM in the future. This abstraction simplifies upgrades and avoids coupling applications directly to a specific model runtime.

---

# 3. Why not let the frontend call Ollama directly?

### Answer

Doing so would tightly couple the frontend to the model runtime and expose internal infrastructure. The gateway provides request validation, standardized APIs, metrics, logging, and a single integration point. It also allows future enhancements such as authentication, rate limiting, caching, and model routing.

---

# 4. What is the role of the AI Agent Orchestrator?

### Answer

The AI Agent Orchestrator coordinates AI reasoning with operational context. Before invoking the LLM, it determines whether information from Prometheus, Kubernetes, or Elasticsearch is required. It gathers that context, enriches the prompt, and forwards it to the LLM Gateway. This produces responses that are grounded in the current state of the platform.

---

# 5. Why use GitOps instead of deploying directly with CI?

### Answer

GitOps keeps Git as the source of truth. CI is responsible for building images and updating manifests, while Argo CD continuously reconciles the cluster to the desired state. This approach provides version control, auditability, self-healing, and simpler rollback.

---

# 6. Why use a dedicated AI node pool?

### Answer

AI workloads have different resource requirements from application services. By isolating them on a dedicated node pool with labels and taints, the platform prevents resource contention, enables independent scaling, and allows AI infrastructure to be disabled when not required, reducing operational costs.

---

# 7. How is the platform secured?

### Answer

Security is implemented using multiple layers:

- Istio mTLS for encrypted service-to-service communication
- AuthorizationPolicy for identity-based access control
- Kubernetes RBAC and Service Accounts
- NetworkPolicy for network isolation
- External Secrets integrated with Google Secret Manager for secret management

---

# 8. How do you observe the health of the AI platform?

### Answer

The platform uses multiple observability signals:

- Prometheus for metrics
- Grafana for dashboards
- Elasticsearch for logs
- Tempo for distributed tracing

Together these provide visibility into availability, latency, errors, and request flow.

---

# 9. Why use Argo Rollouts?

### Answer

Argo Rollouts enables progressive delivery. New versions are released gradually, validated using Prometheus metrics, and automatically rolled back if health checks fail. This reduces deployment risk and avoids exposing all users to a faulty release.

---

# 10. If you had more time, what would you build next?

### Answer

Future enhancements include GPU-enabled node pools, vLLM integration, Retrieval-Augmented Generation (RAG), vector databases, model routing, multi-model support, and multi-cluster GitOps.
