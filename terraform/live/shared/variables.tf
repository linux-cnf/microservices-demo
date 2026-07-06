# -------------------------------------------------------------------
# PURPOSE:
# Defines input variables for project-wide shared infrastructure.
#
# RESPONSIBILITIES:
# - Provide common project and region values for shared resources.
#
# WHY THIS EXISTS?
# Shared infrastructure is provisioned once per GCP project and reused
# by dev, prod, and future environments.
# -------------------------------------------------------------------

variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to apply this config to"
}

variable "region" {
  type        = string
  description = "Region for shared resources"
  default     = "us-central1"
}
