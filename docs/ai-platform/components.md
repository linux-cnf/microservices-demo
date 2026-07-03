# AI Platform Components

## Overview

The AI platform is composed of multiple infrastructure, platform, and application components working together to provide a secure, observable, and production-ready AI environment.

---

# AI Runtime

## ai-ollama

**Purpose**

Provides the local Large Language Model (LLM) inference runtime.

**Responsibilities**

- Hosts AI models
- Executes prompt inference
- Returns generated responses
- Keeps models cached on persistent storage

**Current Model**

- tinyllama

**Future Enhancements**

- vLLM
- Multiple models
- GPU acceleration
- Dynamic model loading

---

# LLM Gateway

## ai-llm-gateway

**Purpose**

Acts as the single entry point for all LLM requests.

**Responsibilities**

- Accept client requests
- Validate input
- Forward prompts to Ollama
- Return standardized responses
- Expose health and metrics endpoints

**Endpoints**

```
POST /chat
GET /healthz
GET /readyz
GET /metrics
```

---

# AI Agent Orchestrator

## ai-agent-orchestrator

**Purpose**

Coordinates AI reasoning with platform context.

Instead of sending every question directly to the LLM, the orchestrator determines whether live platform information should be collected first.

**Responsibilities**

- Route user requests
- Query platform tools
- Build contextual prompts
- Forward enriched prompts to the LLM Gateway
- Return final responses

**Endpoints**

```
POST /agent/chat
GET /healthz
GET /readyz
GET /metrics
```

---

# Platform Tool Integrations

The AI Agent can interact with multiple operational systems.

## Prometheus

Used for:

- Service health
- Availability
- Pod readiness
- Restart counts
- AI metrics

Example questions:

- Is the AI platform healthy?
- Which pods are restarting?
- How many AI requests are failing?

---

## Kubernetes API

Used for:

- Pods
- Deployments
- ReplicaSets
- Events
- Namespaces

Example questions:

- Which AI pods are running?
- Why is my deployment failing?
- Show recent Kubernetes events.

---

## Elasticsearch

Used for:

- Application logs
- Error investigation
- Exception analysis

Example questions:

- Show recent AI errors.
- Find failed requests.
- Search logs for exceptions.

---

## Tempo

Used for:

- Distributed tracing
- Request flow analysis
- Service latency investigation

Example questions:

- Where is request latency increasing?
- Which service is slowing the request?

---

# Redis

## ai-rate-limit-redis

**Purpose**

Provides shared storage for request rate limiting.

**Benefits**

- Prevents abuse
- Protects AI services
- Enables future quota enforcement

---

# GitOps Components

## Argo CD

Responsible for:

- Continuous reconciliation
- Drift detection
- Self-healing
- Declarative deployment

---

## Kustomize

Used for:

- Base manifests
- Environment overlays
- Rollout overlays
- Security overlays

---

# Progressive Delivery

## Argo Rollouts

Provides:

- Canary deployments
- Traffic shifting
- AnalysisTemplate execution
- Automated rollback

---

## Prometheus AnalysisTemplate

Validates deployments using live metrics before promotion.

Benefits:

- Detect unhealthy releases
- Reduce deployment risk
- Fully automated validation

---

# Observability Stack

## Prometheus

Collects metrics from:

- AI Agent Orchestrator
- LLM Gateway
- Kubernetes

---

## Grafana

Visualizes:

- AI dashboards
- Service health
- Request latency
- Error rates

---

## Elasticsearch

Stores platform logs.

Used for:

- Root cause analysis
- Incident investigation

---

## Tempo

Stores distributed traces.

Supports:

- End-to-end request tracing
- Latency analysis

---

# Security Components

## Istio

Provides:

- mTLS
- Traffic management
- Identity-based communication

---

## AuthorizationPolicy

Controls which workloads may communicate.

---

## PeerAuthentication

Enforces mutual TLS.

---

## NetworkPolicy

Provides Layer 3/Layer 4 network isolation.

---

## External Secrets

Synchronizes secrets from Google Secret Manager into Kubernetes.

---

# Infrastructure Components

Infrastructure is provisioned using Terraform.

Resources include:

- GKE Cluster
- AI Node Pool
- IAM
- Artifact Registry
- Networking
- Secret Manager

---

# Component Relationships

```text
Frontend AI Assistant
        │
        ▼
AI Agent Orchestrator
        │
        ├──────────────┐
        ▼              ▼
Prometheus      Kubernetes API
        │              │
        ▼              ▼
Elasticsearch    Tempo
        │
        ▼
LLM Gateway
        │
        ▼
Ollama
```

---

# Summary

Each component has a single, well-defined responsibility. Together they form a modular AI Platform Engineering stack that supports GitOps, observability, security, progressive delivery, and intelligent platform operations.
