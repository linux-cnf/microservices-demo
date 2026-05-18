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

module "github_actions_deployer_compute_storage_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/compute.storageAdmin"
  member         = module.github_actions_deployer_sa.member
}

# Later, if firewall rules are added, uncomment this.
# module "github_actions_deployer_compute_security_admin" {
#   source         = "../../modules/iam-binding"
#   gcp_project_id = var.gcp_project_id
#   role           = "roles/compute.securityAdmin"
#   member         = module.github_actions_deployer_sa.member
# }
