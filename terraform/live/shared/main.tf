# -------------------------------------------------------------------
# PURPOSE:
# Enables project-level Google Cloud APIs required by the platform.
#
# RESPONSIBILITIES:
# - Enable shared APIs once per GCP project.
# - Keep API enablement separate from dev/prod infrastructure.
#
# WHY THIS EXISTS?
# Dev and prod environments consume these APIs, but API enablement is
# project-wide and should not be duplicated in each environment.
# -------------------------------------------------------------------

locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}

module "project_services" {
  source                      = "../../modules/project-services"
  project_id                  = var.gcp_project_id
  activate_apis               = local.base_apis
  disable_services_on_destroy = false
}
