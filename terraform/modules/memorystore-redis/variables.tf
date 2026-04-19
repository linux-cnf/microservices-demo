variable "memorystore" {
  type        = bool
  description = "Enable or disable Memorystore Redis instance"
}

variable "region" {
  type        = string
  description = "Region where the Memorystore Redis instance will be created"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the Memorystore Redis instance will be created"
}
