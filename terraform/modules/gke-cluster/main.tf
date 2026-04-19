resource "google_container_cluster" "my_cluster" {
  name     = var.name
  location = var.zone
  project  = var.gcp_project_id

  deletion_protection = var.deletion_protection

  remove_default_node_pool = true
  initial_node_count       = 1
}
