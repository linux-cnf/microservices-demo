# 🚀 Production-Grade Platform Engineering Lab

This repository transforms Google's Online Boutique microservices application into a production-oriented cloud-native platform used to demonstrate modern DevOps, GitOps, Kubernetes, Observability, Security, Service Mesh, and Platform Engineering practices.

The objective is not only to deploy microservices, but to design, automate, secure, observe, validate, and operate a production-style Kubernetes platform using enterprise-grade tooling and operational workflows.

---

# 🏗️ Platform Architecture

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
Terraform Infrastructure
    │
    ▼
Private GKE Cluster
    │
    ▼
Argo CD GitOps
    │
    ▼
Kubernetes Workloads
    │
    ▼
Observability + Logging + Tracing
```

---

# 🛠️ Technology Stack

| Category                  | Technologies                                       |
| ------------------------- | -------------------------------------------------- |
| Cloud                     | GCP, GKE                                           |
| Infrastructure as Code    | Terraform                                          |
| GitOps                    | Argo CD                                            |
| CI/CD                     | GitHub Actions                                     |
| Containers                | Docker                                             |
| Kubernetes Packaging      | Helm, Kustomize                                    |
| Service Mesh              | Istio                                              |
| Progressive Delivery      | Argo Rollouts                                      |
| Registry                  | Artifact Registry                                  |
| Monitoring                | Prometheus                                         |
| Dashboards                | Grafana                                            |
| Logging                   | Elasticsearch, Kibana, ECK                         |
| Tracing                   | Tempo, OpenTelemetry                               |
| Secrets Management        | External Secrets Operator                          |
| Secret Backend            | Google Secret Manager                              |
| Security                  | RBAC, Workload Identity, AuthorizationPolicy, mTLS |
| Networking                | Private GKE, Cloud NAT, VPC Native Networking      |
| Automation                | Bash                                               |
| Application Communication | gRPC                                               |

---

# 🎯 Platform Engineering Journey

The repository is implemented incrementally using production-oriented phases.

## Phase 1 — Reliability Engineering

Implemented:

* Readiness Probes
* Liveness Probes
* Startup Probes
* Pod Disruption Budgets

Key Goal:

Improve workload reliability and reduce application downtime during deployments and node maintenance.

---

## Phase 2 — GitOps Health Monitoring

Implemented:

* Argo CD Health Customization
* Automated Health Reporting
* Scheduled Health Checks

Key Goal:

Improve operational visibility of GitOps-managed applications.

---

## Phase 3 — Progressive Delivery

Implemented:

* Argo Rollouts
* Canary Deployment Strategy
* Automated Rollout Verification
* Rollout Analysis Templates

Key Goal:

Safely deploy application updates using progressive delivery techniques.

---

## Phase 4 — Automated Rollback Validation

Implemented:

* Prometheus-Based Rollout Analysis
* Automated Rollback Conditions
* Deployment Health Validation

Key Goal:

Automatically prevent unhealthy releases from reaching production traffic.

---

## Phase 5 — Service Mesh Traffic Management

Implemented:

* Istio Service Mesh
* VirtualService Routing
* DestinationRule Policies
* Traffic Splitting
* Service Mesh Metrics

Key Goal:

Introduce advanced traffic management and service-to-service observability.

---

## Phase 6 — Security & Resilience Engineering

Implemented:

* Kiali Service Mesh Dashboard
* STRICT mTLS
* AuthorizationPolicies
* Least-Privilege Service Communication
* Fault Injection Testing
* Security Validation Testing
* Service Mesh Resilience Testing

Key Goal:

Improve platform security, visibility, and failure testing capabilities.

---

# 🔐 Security Features

Implemented security controls include:

* Workload Identity
* External Secrets Operator
* Google Secret Manager Integration
* Kubernetes RBAC
* Network Policies
* STRICT Istio mTLS
* Service-Level Authorization Policies
* Least Privilege Communication Model

---

# 📊 Observability Stack

Monitoring:

* Prometheus
* kube-state-metrics
* Node Exporter

Visualization:

* Grafana

Logging:

* Elasticsearch
* Kibana
* ECK Operator

Tracing:

* Tempo
* OpenTelemetry

Service Mesh Visibility:

* Kiali

---

# 🚀 GitOps Architecture

The platform follows a GitOps operating model.

```text
Git Commit
    │
    ▼
GitHub Actions
    │
    ▼
Container Build
    │
    ▼
Artifact Registry
    │
    ▼
Argo CD
    │
    ▼
Kubernetes Cluster
```

Features:

* App-of-Apps Pattern
* Automated Synchronization
* Self-Healing
* Automated Pruning
* Declarative Infrastructure

---

# 📁 Repository Structure

```text
argocd/                 GitOps applications
terraform/              Infrastructure as Code
kustomize/              Kubernetes customization
helm-chart/             Platform Helm charts
scripts/                Operational automation
istio-manifests/        Original Istio reference manifests
src/                    Application source code
```

---

# 🎓 Learning Outcomes

This repository demonstrates practical implementation of:

* Platform Engineering
* Kubernetes Operations
* GitOps
* Service Mesh
* Progressive Delivery
* Observability Engineering
* Infrastructure as Code
* DevSecOps
* Reliability Engineering
* Production Readiness

---

# 👨‍💻 Target Audience

This repository is designed for:

* DevOps Engineers
* Platform Engineers
* Site Reliability Engineers (SRE)
* Cloud Engineers
* Kubernetes Engineers
* Infrastructure Engineers
* Senior / Lead DevOps Professionals

---

# 📈 Current Platform Capabilities

✅ Private GKE Cluster

✅ GitOps with Argo CD

✅ Progressive Delivery with Argo Rollouts

✅ Service Mesh with Istio

✅ STRICT mTLS

✅ Service-Level Authorization Policies

✅ Centralized Logging

✅ Distributed Tracing

✅ Platform Observability

✅ External Secrets Integration

✅ Workload Identity

✅ Fault Injection Testing

✅ Production-Oriented Operational Workflows

---

# 📌 Project Goal

The primary goal of this repository is to provide a hands-on production-style Platform Engineering lab where engineers can learn, experiment, and demonstrate real-world Kubernetes, DevOps, GitOps, Security, Service Mesh, and Observability practices beyond basic application deployment.

