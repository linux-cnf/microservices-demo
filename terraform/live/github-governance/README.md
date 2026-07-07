# GitHub Governance Terraform

This Terraform live environment manages GitHub repository guardrails for the `microservices-demo` repository.

It is intentionally separated from `terraform/live/prod` because this stack manages GitHub governance, not GCP infrastructure.

Managed resources:

- Protected GitHub environments
- Required reviewers for destructive workflows
- Repository workflow safety controls

Authentication uses the `GITHUB_TOKEN` environment variable.
