module "memorystore_redis" {
  source         = "../../modules/memorystore-redis"
  memorystore    = var.memorystore_enabled
  region         = var.region
  gcp_project_id = var.gcp_project_id

  depends_on = [module.project_services]
}
