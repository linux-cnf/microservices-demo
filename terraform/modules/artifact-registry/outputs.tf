output "repository_id" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "location" {
  description = "Artifact Registry location"
  value       = google_artifact_registry_repository.docker_repo.location
}

output "repository_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}
