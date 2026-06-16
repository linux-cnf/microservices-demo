# =========================================================
# AI Platform IAM
# =========================================================
#
# This file creates a dedicated Google service account for the AI node pool.
# AI infrastructure uses a separate identity so permissions remain isolated
# from the primary and platform-observability node pools.
#
# =========================================================

module "ai_node_pool_service_account" {
  source         = "../../modules/service-account"
  gcp_project_id = var.gcp_project_id

  account_id   = "gke-ai-node-pool-sa"
  display_name = "GKE AI Node Pool Service Account"
}
module "ai_node_pool_default_node_sa" {
  source         = "../../modules/iam-binding"
  gcp_project_id = var.gcp_project_id
  role           = "roles/container.defaultNodeServiceAccount"
  member         = module.ai_node_pool_service_account.member

  depends_on = [module.ai_node_pool_service_account]
}
