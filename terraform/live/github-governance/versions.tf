# -------------------------------------------------------------------
# PURPOSE:
# Defines Terraform and GitHub provider version constraints.
# Keeps GitHub governance automation consistent and reproducible.
# -------------------------------------------------------------------
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.11"
    }
  }
}
