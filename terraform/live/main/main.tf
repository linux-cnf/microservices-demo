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

# NOTE:
# Cloud NAT is currently enabled mainly to provide outbound internet access
# for private GKE nodes so Argo CD can fetch external Git repositories/images.
# This keeps nodes private (no public IPs) while still allowing controlled egress.
module "cloud_nat" {
  source = "../../modules/cloud-nat"

  project_id        = var.gcp_project_id
  region            = var.region
  network_self_link = module.vpc.network_self_link

  router_name = "router-kfounding-dev"
  nat_name    = "nat-kfounding-dev"

  depends_on = [
    module.project_services,
    module.vpc
  ]
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

# External Secrets Operator uses this Google service account
# through GKE Workload Identity to read secrets from Secret Manager.
module "external_secrets_gsm_sa" {
  source = "../../modules/service-account"

  gcp_project_id = var.gcp_project_id
  account_id     = "external-secrets-gsm"
  display_name   = "External Secrets Google Secret Manager"

  depends_on = [module.project_services]
}

# Secret metadata is managed by Terraform.
# Secret value/version is NOT managed by Terraform to avoid storing
# the Slack bot token in Terraform state.
#
# IMPORTANT:
# The secret value should be added manually using:
# gcloud secrets versions add argocd-slack-bot-token --data-file=-
#
# If this long-lived secret survives terraform destroy, import it before plan/apply:
# terraform import google_secret_manager_secret.argocd_slack_bot_token \
#   projects/<PROJECT_ID>/secrets/argocd-slack-bot-token
resource "google_secret_manager_secret" "argocd_slack_bot_token" {
  project   = var.gcp_project_id
  secret_id = "argocd-slack-bot-token"

  replication {
    auto {}
  }

  depends_on = [module.project_services]
}

# Allow only the External Secrets GCP service account to read the Slack token.
resource "google_secret_manager_secret_iam_member" "argocd_slack_token_external_secrets" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.argocd_slack_bot_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.external_secrets_gsm_sa.member

  depends_on = [
    google_secret_manager_secret.argocd_slack_bot_token,
    module.external_secrets_gsm_sa
  ]
}

# Allow Kubernetes service account external-secrets/external-secrets
# to impersonate the GCP service account using Workload Identity.
resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  service_account_id = module.external_secrets_gsm_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[external-secrets/external-secrets]"

  depends_on = [module.external_secrets_gsm_sa]
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

module "github_actions_deployer_compute_storage_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  member         = module.github_actions_deployer_sa.member
  role           = "roles/compute.storageAdmin"
}

# Later, if firewall rules are added, uncomment this.
# module "github_actions_deployer_compute_security_admin" {
#   source         = "../../modules/iam-binding"
#   gcp_project_id = var.gcp_project_id
#   role           = "roles/compute.securityAdmin"
#   member         = module.github_actions_deployer_sa.member
# }
