resource "google_container_cluster" "my_cluster" {
  name           = var.name
  location       = var.region
  node_locations = var.node_locations
  project        = var.gcp_project_id

  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
  }

  deletion_protection = var.deletion_protection

  network    = var.network
  subnetwork = var.subnetwork

  remove_default_node_pool = true
  initial_node_count       = 1

  # This node_config applies ONLY to the temporary default node pool
  # created by GKE during cluster creation.
  # It does NOT affect primary-node-pool or platform-observability.
  # Keep disk size small to avoid quota exhaustion.
  node_config {
    disk_size_gb = 30
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"
  }

  # Ignore temporary default node pool settings after cluster creation
  lifecycle {
    ignore_changes = [
      node_config,
      initial_node_count,
    ]
  }

  datapath_provider = var.datapath_provider
  networking_mode   = "VPC_NATIVE"

  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  timeouts {
    create = "30m"
    update = "40m"
    delete = "30m"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.service_range_name
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks

      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}
