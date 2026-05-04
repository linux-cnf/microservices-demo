resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project       = var.project_id
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.node_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pod_range_name
    ip_cidr_range = var.pod_cidr
  }

  secondary_ip_range {
    range_name    = var.service_range_name
    ip_cidr_range = var.service_cidr
  }
}
