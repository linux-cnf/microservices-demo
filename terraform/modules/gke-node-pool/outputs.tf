output "node_pool_name" {
  description = "Name of the GKE node pool"
  value       = google_container_node_pool.primary_nodes.name
}

output "node_pool_id" {
  description = "ID of the GKE node pool"
  value       = google_container_node_pool.primary_nodes.id
}
