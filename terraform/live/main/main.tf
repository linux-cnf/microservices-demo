# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "artifactregistry.googleapis.com"
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

module "memorystore_redis" {
  source         = "../../modules/memorystore-redis"
  memorystore    = var.memorystore_enabled
  region         = var.region
  gcp_project_id = var.gcp_project_id
  depends_on     = [module.project_services]
}

module "artifact_registry" {
  source         = "../../modules/artifact-registry"
  gcp_project_id = var.gcp_project_id
  region         = var.region
  repository_id  = "microservices-demo"
}

module "gke_cluster" {
  source              = "../../modules/gke-cluster"
  gcp_project_id      = var.gcp_project_id
  name                = var.name
  zone                = var.zone
  region              = var.region
  deletion_protection = false
}

module "gke_node_pool" {
  source         = "../../modules/gke-node-pool"
  gcp_project_id = var.gcp_project_id
  cluster_name   = module.gke_cluster.cluster_name
  location       = module.gke_cluster.location

  node_pool_name = "primary-node-pool"
  machine_type   = "e2-standard-2"
  disk_size_gb   = 30
  disk_type      = "pd-standard"
  image_type     = "COS_CONTAINERD"
  min_node_count = 1
  max_node_count = 2

  depends_on = [module.gke_cluster]
}

module "github_actions_deployer_sa" {
  source         = "../../modules/service-account"
  gcp_project_id = var.gcp_project_id
  account_id     = "github-actions-deployer"
  display_name   = "GitHub Actions Deployer"
}

module "github_actions_deployer_artifactregistry_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/artifactregistry.admin"
  member         = module.github_actions_deployer_sa.member
}

module "github_actions_deployer_compute_viewer" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/compute.viewer"
  member         = module.github_actions_deployer_sa.member
}

module "github_actions_deployer_container_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/container.admin"
  member         = module.github_actions_deployer_sa.member
}

module "github_actions_deployer_serviceaccount_user" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/iam.serviceAccountUser"
  member         = module.github_actions_deployer_sa.member
}

module "github_actions_deployer_serviceusage_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/serviceusage.serviceUsageAdmin"
  member         = module.github_actions_deployer_sa.member
}


