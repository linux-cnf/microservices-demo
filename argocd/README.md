# Argo CD GitOps Platform

## Overview

This directory contains all Argo CD configuration used to deploy and manage the Kubernetes platform using GitOps.

Argo CD continuously watches this Git repository and keeps the Kubernetes cluster state aligned with Git.

In short:

```text
Git = Source of Truth
```

If something changes manually inside the cluster, Argo CD detects drift and automatically restores the expected state from Git.

---

# High-Level Flow

```text
Developer pushes code
        ↓
GitHub Actions CI builds images
        ↓
Images pushed to Artifact Registry
        ↓
CI updates Kustomize image tags
        ↓
Pull Request created
        ↓
PR merged to main
        ↓
Argo CD detects Git change
        ↓
Argo CD syncs Kubernetes cluster
```

---

# App-of-Apps Architecture

This repository uses the **Argo CD app-of-apps pattern**.

Instead of manually applying every application YAML one-by-one, a single root application manages all child applications.

Root application:

```text
platform-root-app.yaml
```

The root app watches:

```text
argocd/apps
```

and automatically deploys all child applications.

This is the recommended production approach for large Kubernetes platforms.

---

# Why App-of-Apps?

Benefits:

- Centralized GitOps management
- Easier scaling of platform applications
- Cleaner bootstrap process
- Better production organization
- Easier onboarding for teams
- Consistent deployment ordering

---

# Current Platform Components

## Core Platform

### projects.yaml

Defines Argo CD Projects.

Projects provide:

- RBAC boundaries
- Allowed repositories
- Allowed namespaces
- Deployment restrictions

---

## External Secrets

### external-secrets-app.yaml

Deploys External Secrets Operator using Helm.

This operator pulls secrets securely from Google Secret Manager into Kubernetes.

---

### external-secrets-resources-app.yaml

Deploys:

- SecretStore
- ExternalSecret
- Kubernetes ServiceAccount

Used for secure secret synchronization.

---

## Observability Stack

### observability-app.yaml

Deploys:

- Prometheus
- Grafana
- Alertmanager

Used for metrics, dashboards, and alerting.

---

## Logging Stack

### eck-operator-app.yaml

Deploys Elastic Cloud on Kubernetes Operator.

Required before Elasticsearch resources can be created.

---

### logging-app.yaml

Deploys:

- Elasticsearch
- Kibana

Used for centralized logging.

---

### logging-agent-app.yaml

Deploys Elastic Agent.

Collects logs from Kubernetes nodes and workloads.

---

## Tracing Stack

### tracing-app.yaml

Deploys distributed tracing components.

Used for request tracing and observability.

---

## Application Workloads

### boutique-app.yaml

Deploys the Online Boutique microservices application using Kustomize.

---

# Sync Waves

Applications are deployed using Argo CD sync waves.

Sync waves control deployment order.

Example:

```text
Lower number deploys first
Higher number deploys later
```

Current order:

| Sync Wave | Component |
|---|---|
| -3 | Namespace + Service Accounts |
| -2 | External Secrets Operator |
| -1 | External Secrets resources |
| 0 | ECK Operator |
| 1 | Observability |
| 2 | Logging |
| 3 | Logging Agent |
| 4 | Tracing |
| 5 | Boutique Application |

This prevents dependency and CRD timing issues.

---

# Health Checks

Custom health checks are configured using:

```text
argocd-cm-health-patch.yaml
```

This improves visibility for:

- app-of-apps health
- child app health
- sync status
- progressive deployment tracking

---

# Notifications

Argo CD notifications are configured using:

```text
argocd-notifications-cm.yaml
```

Notifications are sent to Slack for:

- Sync failures
- Health degradation
- Drift detection
- OutOfSync applications

---

# Secret Management

Secrets are NOT stored in Git.

Secrets are securely managed using:

- Google Secret Manager
- External Secrets Operator
- GKE Workload Identity

Flow:

```text
Google Secret Manager
        ↓
External Secrets Operator
        ↓
Kubernetes Secret
        ↓
Argo CD Notifications
```

This is production-grade secret management.

---

# Bootstrap Flow

Cluster bootstrap workflow:

```text
Terraform creates infrastructure
        ↓
cluster-bootstrap workflow runs
        ↓
Argo CD installed
        ↓
Health checks applied
        ↓
Notifications configured
        ↓
Root app deployed
        ↓
Child apps automatically synced
```

---

# Manual Testing

Apply only root app:

```bash
kubectl apply -f argocd/platform-root-app.yaml -n argocd
```

Argo CD will automatically deploy child apps.

---

# Useful Commands

## List Argo CD applications

```bash
kubectl get application -n argocd
```

---

## Check application health

```bash
kubectl get application -n argocd
```

---

## Force refresh application

```bash
kubectl annotate application boutique \
  -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

---

## Check External Secrets

```bash
kubectl get externalsecret -A
```

---

## Check Argo CD projects

```bash
kubectl get appproject -n argocd
```

---

# Directory Structure

```text
argocd/
├── README.md
├── install.yaml
├── platform-root-app.yaml
├── argocd-cm-health-patch.yaml
├── argocd-notifications-cm.yaml
│
├── apps/
│   ├── projects.yaml
│   ├── external-secrets-app.yaml
│   ├── external-secrets-resources-app.yaml
│   ├── eck-operator-app.yaml
│   ├── observability-app.yaml
│   ├── logging-app.yaml
│   ├── logging-agent-app.yaml
│   ├── tracing-app.yaml
│   ├── boutique-app.yaml
│   │
│   └── external-secrets/
│       ├── kustomization.yaml
│       ├── secret-store.yaml
│       └── argocd-slack-token.yaml
```

---

# Production Design Goals

This setup focuses on:

- GitOps-first deployments
- Secure secret management
- Private GKE cluster design
- Production-grade observability
- Automated drift correction
- Slack alerting
- Infrastructure as Code
- Clean bootstrap automation
- Beginner-friendly operational flow

