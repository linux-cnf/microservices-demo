output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.my_cluster.name
}

output "location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.my_cluster.location
}

output "id" {
  description = "ID of the GKE cluster"
  value       = google_container_cluster.my_cluster.id
}

output "endpoint" {
  description = "GKE control plane endpoint"
  value       = google_container_cluster.my_cluster.endpoint
}

output "ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}
