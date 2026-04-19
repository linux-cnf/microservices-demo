variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the GKE cluster will be created"
}

variable "name" {
  type        = string
  description = "Name of the GKE cluster"
}

variable "zone" {
  type        = string
  description = "Zone where the GKE cluster will be created"
}

variable "region" {
  type        = string
  description = "Region of the GKE cluster"
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to protect the GKE cluster from accidental deletion"
  default     = false
}
