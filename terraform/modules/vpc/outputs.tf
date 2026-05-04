output "network_name" {
  value = google_compute_network.this.name
}

output "network_self_link" {
  value = google_compute_network.this.self_link
}

output "subnet_name" {
  value = google_compute_subnetwork.this.name
}

output "subnet_self_link" {
  value = google_compute_subnetwork.this.self_link
}

output "pod_range_name" {
  value = var.pod_range_name
}

output "service_range_name" {
  value = var.service_range_name
}
