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

module "artifact_registry_ai_microservices" {
  source         = "../../modules/artifact-registry"
  gcp_project_id = var.gcp_project_id
  region         = var.region
  repository_id  = "ai-microservices"
}
