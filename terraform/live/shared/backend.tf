# -------------------------------------------------------------------
# PURPOSE:
# Stores the Terraform state for project-wide shared infrastructure.
#
# RESPONSIBILITIES:
# - Manage resources shared across all environments.
# - Keep shared state independent from dev and prod.
#
# WHY THIS EXISTS?
# Shared resources should be provisioned only once per GCP project.
# Dev and prod consume these resources but must not recreate them.
# -------------------------------------------------------------------

terraform {
  backend "gcs" {
    bucket = "project-19d98bfe-795f-49b8-af0-tfstate"
    prefix = "live/shared"
  }
}
