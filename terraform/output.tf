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

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.my_cluster.name
}

output "gke_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.my_cluster.location
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "artifact_registry_location" {
  description = "Artifact Registry location"
  value       = google_artifact_registry_repository.docker_repo.location
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}
