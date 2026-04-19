resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.gcp_project_id
  location      = var.region
  repository_id = var.repository_id
  format        = var.format

  description = "Docker repository for microservices-demo images"

  lifecycle {
    prevent_destroy = false
  }
}
