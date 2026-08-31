# Production-Grade Platform Engineering Lab

This repository extends Google's Online Boutique sample into a production-oriented
platform engineering lab on Google Cloud. It keeps the polyglot microservices
application while adding environment-aware infrastructure, GitOps delivery,
progressive rollouts, service-mesh security, observability, centralized logging,
distributed tracing, and an optional AI platform.

## Architecture

```text
GitHub (develop/main)
        |
        v
GitHub Actions -----> Artifact Registry
        |
        v
Terraform (shared, dev, prod)
        |
        v
Private-node GKE clusters
        |
        v
Argo CD app-of-apps
        |
        +--> Kustomize: Online Boutique, Istio policies, Argo Rollouts
        +--> Helm: Prometheus/Grafana, Elasticsearch/Kibana, Tempo, Kiali
        +--> External Secrets Operator -> Google Secret Manager
```

The GKE nodes use private addresses. The Terraform live environments configure
Cloud NAT for controlled outbound access; the platform image-mirroring workflow
can also copy approved third-party images into Artifact Registry.

## Major components

| Area | Implementation |
| --- | --- |
| Application | Online Boutique microservices under `src/`, primarily communicating over gRPC |
| Infrastructure | Reusable Terraform modules and isolated `shared`, `dev`, and `prod` live states |
| GitOps | Argo CD app-of-apps with environment-specific roots |
| Packaging | Kustomize bases/components/overlays and platform Helm charts |
| Delivery | Argo Rollouts canaries with Prometheus analysis |
| Service mesh | Istio ingress, traffic policy, strict mTLS, authorization policies, and Kiali |
| Metrics | Prometheus, Alertmanager, kube-state-metrics, node-exporter, and Grafana dashboards |
| Logging | ECK-managed Elasticsearch and Kibana with Elastic Agent |
| Tracing | Tempo and OpenTelemetry Collector with Istio tracing configuration |
| Secrets | External Secrets Operator, Google Secret Manager, and Workload Identity |
| Security | Network policies, RBAC, image auditing, Gitleaks, Checkov, Trivy, and Zizmor |
| AI platform | Ollama, LLM gateway, agent orchestrator, Redis rate limiting, observability, Istio policy, and optional canary rollout |

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/` | Application and AI service source code |
| `kubernetes-manifests/` | Direct-deployment Online Boutique manifests |
| `kustomize/` | Base, reusable components, dev/prod overlays, and AI manifests |
| `helm-chart/` | Observability, logging, tracing, Kiali, and logging-agent charts |
| `argocd/` | Environment roots, Applications, projects, health checks, and notifications |
| `terraform/modules/` | Reusable GCP modules |
| `terraform/live/` | `shared`, `dev`, `prod`, and GitHub-governance states |
| `scripts/` | Bootstrap, image mirroring, smoke testing, rollout, and operational helpers |
| `.github/workflows/` | CI, infrastructure, bootstrap, security, and validation workflows |
| `docs/` | Development, release, rollout, and AI platform guides |
| `release/` | Generated release manifests |

## Environment and branch strategy

| Environment | Git branch | Argo CD root | Workload overlay |
| --- | --- | --- | --- |
| Development | `develop` | `argocd/platform-root-app-dev.yaml` | `kustomize/environments/dev` |
| Production | `main` | `argocd/platform-root-app-prod.yaml` | `kustomize/environments/prod` |

Changes are developed and validated through pull requests into `develop`, then
promoted to `main` through the repository's release process. Argo CD applications
use automated synchronization, pruning, and self-healing.

The AI infrastructure is currently production-only at the workflow/GitOps level:
the AI bootstrap and node-pool disable workflows expose only `prod`, and the
optional AI Argo CD Application tracks `main`. Although a dev AI node-pool module
exists in Terraform, it is not part of the supported end-to-end dev bootstrap.

## Prerequisites

The exact tools depend on the workflow, but local operators normally need:

- Google Cloud CLI authenticated to the target project
- Terraform (the workflows currently use 1.14.8)
- `kubectl` and access to the target GKE cluster
- Helm and Kustomize (or `kubectl kustomize`)
- Argo CD CLI for optional GitOps inspection
- Docker only when building images locally

Cloud automation also expects repository/environment secrets for Workload
Identity Federation and the GCP project. Do not place credentials in Git.

## Provision and bootstrap

The supported automation is exposed as manually dispatched GitHub Actions:

1. `platform-bootstrap.yml` validates Terraform and can orchestrate infrastructure,
   approved image mirroring, GitHub governance, and the production AI bootstrap.
2. `infra-main.yml` plans or applies `terraform/live/shared`, `dev`, or `prod`.
3. `scripts/cluster-bootstrap.sh` installs/configures Argo CD and applies the
   environment-specific root application from an authenticated operator host.
4. Argo CD reconciles platform Helm charts and the appropriate Kustomize overlay.
5. `smoke-test.yml` or `scripts/smoke-test.sh` performs cluster checks.

Review workflow inputs and destructive confirmations before running automation.
`platform-full-destroy.yml` deliberately protects shared resources and requires
environment-specific approval.

For local manifest exploration without cloud changes:

```bash
kubectl kustomize kustomize/environments/dev >/tmp/dev-rendered.yaml
kubectl kustomize kustomize/environments/prod >/tmp/prod-rendered.yaml
helm dependency build helm-chart/observability
helm template observability helm-chart/observability \
  --namespace monitoring -f helm-chart/observability/values-dev.yaml >/tmp/observability.yaml
```

## CI/CD and security validation

- `ci-main.yaml` tests changed application services, builds images on `main` or
  release branches, and opens GitOps image-tag pull requests.
- `ai-platform-ci.yml` validates/builds changed AI services on `main` and opens
  an AI GitOps update pull request.
- Kustomize, Helm, Terraform, raw manifests, and workflow YAML have dedicated CI.
- `devsecops-security-scan.yml` orchestrates Gitleaks, Checkov, Trivy, and Zizmor.
- `tools/image-auditor/` checks running Pod images against approved Artifact
  Registry prefixes.

## Useful checks

```bash
# Render workload overlays
kubectl kustomize kustomize/environments/dev >/dev/null
kubectl kustomize kustomize/environments/prod >/dev/null

# Validate Terraform formatting
terraform fmt -check -recursive terraform

# Inspect GitOps and rollouts
kubectl get applications -n argocd
kubectl get rollouts -A
kubectl argo rollouts get rollout frontend -n boutique

# Inspect platform health
kubectl get pods -A
kubectl get servicemonitors,prometheusrules -A
kubectl get externalsecrets -A

# Build and run the image auditor
make image-auditor-test
./scripts/run-image-auditor.sh --namespace boutique
```

If reconciliation stalls, inspect the Argo CD Application, its events, the
rendered Kustomize output, and the controller logs before making manual cluster
changes. For canary failures, inspect the Rollout and AnalysisRun together with
the Prometheus query result.

## Detailed documentation

- [Argo CD control plane](argocd/README.md)
- [Kustomize layouts and components](kustomize/README.md)
- [Platform Helm charts](helm-chart/README.md)
- [Istio reference manifests](istio-manifests/README.md)
- [AI platform](docs/ai-platform/README.md)
- [AI deployment guide](docs/ai-platform/deployment-guide.md)
- [AI operations runbook](docs/ai-platform/operations/runbook.md)
- [Argo Rollouts analysis](docs/rollouts/phase4-prometheus-analysis.md)
- [Release process](docs/releasing/README.md)
- [GitHub Actions workflows](.github/workflows/README.md)
- [Development guide](docs/development-guide.md)

This is a lab/reference implementation. Review cost, capacity, access controls,
backup requirements, and organization policy before adapting it for production.
