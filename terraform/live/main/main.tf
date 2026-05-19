# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0

locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com"
  ]

  memorystore_apis = var.memorystore_enabled ? ["redis.googleapis.com"] : []
  activate_apis    = concat(local.base_apis, local.memorystore_apis)
}

module "project_services" {
  source                      = "../../modules/project-services"
  project_id                  = var.gcp_project_id
  activate_apis               = local.activate_apis
  disable_services_on_destroy = false
}
