variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the service account will be created"
}

variable "account_id" {
  type        = string
  description = "Service account ID"
}

variable "display_name" {
  type        = string
  description = "Display name for the service account"
}
