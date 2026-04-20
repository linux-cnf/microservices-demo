resource "google_container_node_pool" "primary_nodes" {
  name     = var.node_pool_name
  cluster  = var.cluster_name
  location = var.location
  project  = var.gcp_project_id

  node_count = var.min_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    image_type   = var.image_type

    labels = var.node_labels

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
