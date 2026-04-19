variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the Artifact Registry repository will be created"
}

variable "region" {
  type        = string
  description = "Region for the Artifact Registry repository"
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository name"
  default     = "microservices-demo"
}

variable "format" {
  type        = string
  description = "Artifact Registry repository format"
  default     = "DOCKER"
}
