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

module "github_actions_deployer_secretmanager_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/secretmanager.admin"
  member         = module.github_actions_deployer_sa.member
}

module "github_actions_deployer_compute_storage_admin" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/compute.storageAdmin"
  member         = module.github_actions_deployer_sa.member
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

resource "google_project_iam_member" "gke_default_node_artifact_registry_reader" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  depends_on = [module.project_services]
}
resource "google_project_iam_member" "gke_default_node_artifact_registry_reader" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  depends_on = [module.project_services]
}

# Later, if firewall rules are added, uncomment this.
# module "github_actions_deployer_compute_security_admin" {
#   source         = "../../modules/iam-binding"
#   gcp_project_id = var.gcp_project_id
#   role           = "roles/compute.securityAdmin"
#   member         = module.github_actions_deployer_sa.member
# }
