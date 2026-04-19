variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "activate_apis" {
  type        = list(string)
  description = "List of APIs to enable"
}

variable "disable_services_on_destroy" {
  type        = bool
  description = "Whether services should be disabled on destroy"
  default     = false
}
