# Argo CD GitOps Control Plane

## Overview

This directory contains the complete GitOps control plane responsible for deploying, reconciling, monitoring, and managing the Kubernetes platform.

Argo CD continuously reconciles the desired state stored in Git with the live cluster state, ensuring workloads remain synchronized, recover automatically from configuration drift, and follow a fully declarative deployment model.

Core Principle:

```text
Git = Desired State
Kubernetes = Actual State
Argo CD = Reconciliation Engine
```

Any manual modification performed inside the cluster is detected as drift and automatically corrected according to the Git-defined configuration.

---

# GitOps Deployment Flow

```text
Developer
    │
    ▼
GitHub Repository
    │
    ▼
GitHub Actions CI/CD
    │
    ▼
Artifact Registry
    │
    ▼
GitOps Manifest Update
    │
    ▼
Pull Request Approval
    │
    ▼
Merge to Main
    │
    ▼
Argo CD Reconciliation
    │
    ▼
Kubernetes Cluster
```

This workflow eliminates imperative deployments and ensures all changes are auditable and reproducible.

---

# App-of-Apps Architecture

The platform follows the Argo CD App-of-Apps pattern.

Rather than managing individual applications manually, a single root application controls the entire platform deployment lifecycle.

Root Application:

```text
platform-root-app.yaml
```

Managed Path:

```text
argocd/apps/
```

Deployment Flow:

```text
platform-root
      │
      ├── external-secrets
      ├── observability
      ├── logging
      ├── tracing
      ├── argo-rollouts
      ├── istio
      ├── kiali
      └── boutique
```

Benefits:

* Centralized GitOps management
* Consistent deployment ordering
* Simplified cluster bootstrap
* Scalable platform architecture
* Reduced operational complexity

---

# Platform Components

## GitOps Foundation

### platform-root-app.yaml

Bootstrap application responsible for managing all platform applications.

### projects.yaml

Defines Argo CD Projects used for:

* Repository restrictions
* Namespace restrictions
* RBAC boundaries
* Deployment governance

---

# External Secrets Platform

## external-secrets-app.yaml

Deploys External Secrets Operator.

Responsibilities:

* Secret synchronization
* Secret lifecycle management
* Secret rotation support

## external-secrets-resources-app.yaml

Deploys:

* SecretStore
* ExternalSecret
* Service Accounts

Provides secure integration between Kubernetes and Google Secret Manager.

---

# Progressive Delivery Platform

## argo-rollouts-app.yaml

Deploys Argo Rollouts controller.

Capabilities:

* Canary deployments
* Progressive delivery
* Automated promotion
* Automated rollback
* Analysis templates

Used by:

```text
frontend rollout
```

---

# Service Mesh Platform

## istio-base-app.yaml

Installs Istio CRDs.

## istiod-app.yaml

Deploys Istio control plane.

## istio-ingressgateway-app.yaml

Deploys ingress gateway used for north-south traffic.

## kiali-app.yaml

Deploys Kiali service mesh dashboard.

Provides:

* Traffic visualization
* mTLS visibility
* Service dependency graph
* Error and latency analysis

---

# Observability Platform

## observability-app.yaml

Deploys:

* Prometheus
* Alertmanager
* Grafana

Responsibilities:

* Metrics collection
* Alerting
* Dashboard visualization

---

# Logging Platform

## eck-operator-app.yaml

Deploys Elastic Cloud on Kubernetes Operator.

Required before Elasticsearch resources are created.

## logging-app.yaml

Deploys:

* Elasticsearch
* Kibana

Responsibilities:

* Centralized log aggregation
* Log retention
* Log analysis

## logging-agent-app.yaml

Deploys Elastic Agent.

Responsibilities:

* Node log collection
* Workload log collection
* Elasticsearch ingestion

---

# Distributed Tracing Platform

## tracing-app.yaml

Deploys:

* Tempo
* OpenTelemetry Collector

Responsibilities:

* Distributed tracing
* Request path visualization
* Service latency analysis

---

# Application Platform

## boutique-app.yaml

Deploys the Online Boutique microservices application.

Managed through:

```text
Kustomize
+
Argo CD
+
Argo Rollouts
+
Istio
```

---

# Deployment Ordering (Sync Waves)

Platform applications are deployed using Argo CD Sync Waves.

Purpose:

* CRDs deployed before CRs
* Dependencies deployed before consumers
* Deterministic bootstrap sequence

Current Ordering:

| Wave | Component                    |
| ---- | ---------------------------- |
| -3   | Namespaces, Service Accounts |
| -2   | External Secrets Operator    |
| -1   | External Secrets Resources   |
| 0    | ECK Operator                 |
| 1    | Observability                |
| 2    | Logging                      |
| 3    | Logging Agent                |
| 4    | Tracing                      |
| 5    | Argo Rollouts                |
| 6    | Istio                        |
| 7    | Kiali                        |
| 8    | Boutique                     |

---

# Health Management

## argocd-cm-health-patch.yaml

Custom health checks extend native Argo CD health evaluation.

Benefits:

* Improved application visibility
* Better App-of-Apps health reporting
* Rollout status visibility
* Reduced false unhealthy states

Additional documentation:

```text
HEALTH-CUSTOMIZATION.md
```

---

# Notification Platform

## argocd-notifications-cm.yaml

Provides Slack integration for operational events.

Events:

* Sync failures
* Health degradation
* OutOfSync applications
* Drift detection
* Deployment failures

---

# Secret Management Architecture

Secrets are never stored inside Git.

Architecture:

```text
Google Secret Manager
          │
          ▼
External Secrets Operator
          │
          ▼
Kubernetes Secret
          │
          ▼
Application Consumption
```

Security Components:

* Google Secret Manager
* External Secrets Operator
* Workload Identity
* Kubernetes RBAC

---

# Bootstrap Workflow

Cluster initialization sequence:

```text
Terraform Infrastructure
          │
          ▼
GKE Cluster Creation
          │
          ▼
Argo CD Installation
          │
          ▼
Health Customization
          │
          ▼
Notifications Configuration
          │
          ▼
platform-root Deployment
          │
          ▼
Platform Applications
          │
          ▼
Application Workloads
```

---

# Operational Commands

## List Applications

```bash
kubectl get application -n argocd
```

## Check Application Details

```bash
argocd app get <application-name>
```

## Refresh Application

```bash
kubectl annotate application <application-name> \
  -n argocd \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

## Check Projects

```bash
kubectl get appproject -n argocd
```

## Check External Secrets

```bash
kubectl get externalsecret -A
```

## Check Sync Status

```bash
argocd app list
```

---

# Directory Structure

```text
argocd/
├── install.yaml
├── platform-root-app.yaml
├── argocd-cm-health-patch.yaml
├── argocd-notifications-cm.yaml
├── HEALTH-CUSTOMIZATION.md
│
├── apps/
│   ├── projects.yaml
│   ├── argo-rollouts-app.yaml
│   ├── boutique-app.yaml
│   ├── external-secrets-app.yaml
│   ├── external-secrets-resources-app.yaml
│   ├── eck-operator-app.yaml
│   ├── observability-app.yaml
│   ├── logging-app.yaml
│   ├── logging-agent-app.yaml
│   ├── tracing-app.yaml
│   ├── istio-base-app.yaml
│   ├── istiod-app.yaml
│   ├── istio-ingressgateway-app.yaml
│   └── kiali-app.yaml
```

---

# Design Principles

This GitOps control plane is designed around:

* Declarative Infrastructure
* GitOps-First Operations
* Automated Drift Remediation
* Progressive Delivery
* Platform Observability
* Secure Secret Management
* Service Mesh Security
* Production-Grade Kubernetes Operations
* Reproducible Cluster Bootstrap
* Least-Privilege Access Control

---

# Key Outcomes

Implemented capabilities include:

✅ App-of-Apps GitOps Architecture

✅ Automated Reconciliation

✅ Self-Healing Deployments

✅ Progressive Delivery

✅ Service Mesh Integration

✅ Centralized Logging

✅ Distributed Tracing

✅ Metrics and Alerting

✅ Secure Secret Management

✅ Health Monitoring

✅ Slack Notifications

✅ Production-Oriented Platform Automation

This directory represents the GitOps control plane responsible for operating the entire Kubernetes platform.

