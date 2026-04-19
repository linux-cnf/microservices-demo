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
