# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0

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

module "vpc" {
  source = "../../modules/vpc"

  project_id = var.gcp_project_id
  region     = var.region

  network_name = "vpc-kfounding-dev"
  subnet_name  = "subnet-us-central1-dev"

  node_cidr    = "10.10.0.0/20"
  pod_cidr     = "10.20.0.0/18"
  service_cidr = "10.30.0.0/22"

  pod_range_name     = "pods-us-central1-dev"
  service_range_name = "services-us-central1-dev"

  depends_on = [module.project_services]
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

module "artifact_registry_platform_observability" {
  source         = "../../modules/artifact-registry"
  gcp_project_id = var.gcp_project_id
  region         = var.region
  repository_id  = "platform-observability"
}

module "gke_cluster" {
  source              = "../../modules/gke-cluster"
  gcp_project_id      = var.gcp_project_id
  name                = var.name
  zone                = var.zone
  region              = var.region
  deletion_protection = false

  network    = module.vpc.network_self_link
  subnetwork = module.vpc.subnet_self_link

  pod_range_name     = module.vpc.pod_range_name
  service_range_name = module.vpc.service_range_name

  datapath_provider = "ADVANCED_DATAPATH"

  enable_private_nodes    = true
  enable_private_endpoint = false
  master_ipv4_cidr_block  = "172.16.0.0/28"

  master_authorized_networks = [
    {
      cidr_block   = "163.227.186.128/30"
      display_name = "on-prem-bastion"
    }
  ]

  depends_on = [
    module.project_services,
    module.vpc
  ]
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

  max_pods_per_node = 64

  depends_on = [module.gke_cluster]
}

module "gke_node_pool_platform_observability" {
  source         = "../../modules/gke-node-pool"
  gcp_project_id = var.gcp_project_id
  cluster_name   = module.gke_cluster.cluster_name
  location       = module.gke_cluster.location

  node_pool_name = "platform-observability"
  machine_type   = "e2-highmem-2"
  disk_size_gb   = 30
  disk_type      = "pd-standard"
  image_type     = "COS_CONTAINERD"
  min_node_count = 1
  max_node_count = 2

  max_pods_per_node = 64

  node_labels = {
    workload = "observability"
    tier     = "platform"
  }

  node_taints = [
    {
      key    = "dedicated"
      value  = "observability"
      effect = "NO_SCHEDULE"
    }
  ]

  depends_on = [module.gke_cluster]
}

module "github_actions_deployer_sa" {
  source         = "../../modules/service-account"
  gcp_project_id = var.gcp_project_id
  account_id     = "github-actions-deployer"
  display_name   = "GitHub Actions Deployer"
}

module "github_actions_deployer_compute_network_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/compute.networkAdmin"
  member         = module.github_actions_deployer_sa.member
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

# Later, if firewall rules are added, uncomment this.
#module "github_actions_deployer_compute_security_admin" {
#  source         = "../../modules/iam-binding"
#  gcp_project_id = var.gcp_project_id
#  role           = "roles/compute.securityAdmin"
#  member         = module.github_actions_deployer_sa.member
#}
