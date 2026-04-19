resource "google_service_account" "service_account" {
  project      = var.gcp_project_id
  account_id   = var.account_id
  display_name = var.display_name
}
