variable "gcp_project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "tfstate_bucket_name" {
  type = string
}
