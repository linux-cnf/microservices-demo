# NOTE:
# Cloud NAT is currently enabled mainly to provide outbound internet access
# for private GKE nodes.
#
# Current required use case:
# - Argo CD repo-server needs HTTPS egress to GitHub to fetch public Git repos.
# - Private GKE nodes do not have public IPs, so they need NAT for outbound internet.
#
# This is intentionally kept as a small, regional NAT setup for the dev cluster.
# Review before expanding usage for broader production workloads.

resource "google_compute_router" "this" {
  project = var.project_id
  name    = var.router_name
  region  = var.region
  network = var.network_self_link
}

resource "google_compute_router_nat" "this" {
  project = var.project_id
  name    = var.nat_name
  router  = google_compute_router.this.name
  region  = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
