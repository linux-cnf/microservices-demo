variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the IAM binding will be applied"
}

variable "role" {
  type        = string
  description = "IAM role to bind"
}

variable "member" {
  type        = string
  description = "IAM member to bind the role to"
}
