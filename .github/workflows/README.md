# GitHub Actions workflows

The workflows in this directory validate application, infrastructure, GitOps,
and security changes and provide manually approved platform operations.

## Continuous integration

| Workflow | Trigger and purpose |
| --- | --- |
| `ci-main.yaml` | On `main` and `release/*`, tests changed application services, validates Kustomize, builds/pushes images, and opens an image-tag PR |
| `ci-pr.yaml` | Manual compatibility workflow for code and GKE deployment tests against a selected ref |
| `app-ci.yml` | Renders the Kustomize application when Kustomize files change |
| `kustomize-build-ci.yaml` | Renders the base and component-combination test fixtures on pull requests and `main` |
| `helm-chart-ci.yaml` | Lints and templates the repository Helm charts |
| `kubevious-manifests-ci.yaml` | Reviews raw Kubernetes manifests and selected Helm charts |
| `terraform-validate-ci.yaml` | Checks Terraform formatting, initialization, validation, and generated-file hygiene |
| `github-actions-ci.yml` | Runs Prettier, yamllint, and actionlint for workflow changes |

## Delivery and operations

| Workflow | Purpose |
| --- | --- |
| `platform-bootstrap.yml` | Manual orchestration for validation, governance, infrastructure, image mirroring, and optional AI bootstrap |
| `infra-main.yml` | Plans or applies the `shared`, `dev`, or `prod` Terraform live environment |
| `mirror-platform-images.yml` | Mirrors approved third-party images to Artifact Registry |
| `platform-full-destroy.yml` | Explicitly confirmed dev/prod teardown; shared infrastructure remains protected |
| `smoke-test.yml` | Manual GKE workload and frontend smoke test |
| `ai-platform-bootstrap.yml` | Enables the production AI node pool and bootstraps the selected CPU model profile |
| `ai-nodepool-disable.yml` | Disables only the production AI node pool |
| `ai-platform-ci.yml` | Builds changed AI services and opens normal/canary GitOps update PRs |

AI workflow inputs currently expose only `prod`; they do not provide a supported
development AI deployment path.

## Security

`devsecops-security-scan.yml` runs on pull requests and manual dispatch. It calls
the reusable Gitleaks, Checkov, Trivy, and Zizmor workflows. Some scanners are
configured as reporting controls (`soft_fail` or `exit-code: 0`), so review their
findings even when the overall workflow succeeds.

## Authentication and safety

Cloud workflows authenticate through GitHub OIDC/Google Workload Identity
Federation using repository secrets. Do not copy credentials into workflow files.
Apply and destroy workflows use explicit inputs, concurrency controls, and—in
production-sensitive cases—protected GitHub environments.

Application image updates are promoted through pull requests. `develop` is the
development branch and `main` is production; environment-specific Argo CD
Applications track those branches respectively.
