# -------------------------------------------------------------------
# PURPOSE:
# Creates a reusable Google Kubernetes Engine node pool.
#
# RESPONSIBILITIES:
# - Provision node pools with autoscaling, labels, taints, secure node
#   settings, service account, and lifecycle management.
#
# WHY THIS EXISTS?
# All environments should create node pools in a consistent way while
# still allowing environment-specific configuration from live folders.
# -------------------------------------------------------------------
resource "google_container_node_pool" "primary_nodes" {
  name           = var.node_pool_name
  cluster        = var.cluster_name
  location       = var.location
  node_locations = var.node_locations
  project        = var.gcp_project_id

  initial_node_count = var.initial_node_count

  autoscaling {
    total_min_node_count = var.total_min_node_count
    total_max_node_count = var.total_max_node_count
    location_policy      = var.location_policy
  }

  max_pods_per_node = var.max_pods_per_node

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    image_type   = var.image_type

    labels = var.node_labels

    resource_labels = {
      managed_by = "terraform"
      cluster    = var.cluster_name
      node_pool  = var.node_pool_name
      env        = lookup(var.node_labels, "env", "unknown")
    }

    service_account = var.service_account
    oauth_scopes    = var.oauth_scopes

    metadata = {
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    dynamic "taint" {
      for_each = var.node_taints

      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
