# argocd

## Overview
This directory contains **Argo CD Application manifests** for platform and application deployment using GitOps.

---

## Applications

- **boutique-app**
  - Deploys the Online Boutique application

- **observability-app**
  - Deploys Prometheus, Grafana, and Alertmanager

- **logging-app**
  - Deploys Elasticsearch and Kibana

- **logging-agent-app**
  - Deploys Elastic Agent for log collection

- **eck-operator-app**
  - Deploys the Elastic Cloud on Kubernetes operator

- **platform-root-app**
  - Optional parent app for future **app-of-apps** pattern

---

## Recommended Deployment Order

1. eck-operator-app  
2. observability-app  
3. logging-app  
4. logging-agent-app  
5. boutique-app  

---

## Apply Applications

Apply a single app during testing:

```bash
kubectl apply -f argocd/logging-app.yaml -n argocd

Apply all current child apps manually as needed:
kubectl apply -f argocd/observability-app.yaml -n argocd
kubectl apply -f argocd/eck-operator-app.yaml -n argocd
kubectl apply -f argocd/logging-app.yaml -n argocd
kubectl apply -f argocd/logging-agent-app.yaml -n argocd
kubectl apply -f argocd/boutique-app.yaml -n argocd

Workflow Pattern
Update Helm/Kustomize source or Argo CD app manifest
Commit changes to Git
Apply a single child app for testing, if needed
In production flow, Argo CD syncs desired state from Git

Production Notes
Keep Git as source of truth
Child apps can be tested individually
platform-root-app.yaml is prepared for future app-of-apps usage
No infra-bootstrap change is required yet
Use sync waves to maintain clean deployment order

Structure
argocd/
├── README.md
├── boutique-app.yaml
├── eck-operator-app.yaml
├── logging-agent-app.yaml
├── logging-app.yaml
├── observability-app.yaml
└── platform-root-app.yaml
