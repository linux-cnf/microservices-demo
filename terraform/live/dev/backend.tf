# -------------------------------------------------------------------
# PURPOSE:
# Stores the Terraform state for the development environment.
#
# RESPONSIBILITIES:
# - Keep development infrastructure state isolated from production.
# - Prevent accidental changes to production resources.
#
# WHY THIS EXISTS?
# Each long-lived environment must have an independent Terraform
# state. This allows dev and prod to be planned and applied
# independently while sharing the same Terraform modules.
# -------------------------------------------------------------------

terraform {
  backend "gcs" {
    bucket = "project-19d98bfe-795f-49b8-af0-tfstate"
    prefix = "live/dev"
  }
}
