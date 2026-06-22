# -------------------------------------------------------------------
# PURPOSE:
# Configures the GitHub provider for repository governance resources.
# Provider authentication is supplied through the GITHUB_TOKEN env var.
# -------------------------------------------------------------------
provider "github" {
  owner = var.github_owner
}
