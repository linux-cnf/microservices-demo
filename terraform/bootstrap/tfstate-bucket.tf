# ==========================================================
# Terraform State Bucket Hardening
# ==========================================================
#
# PURPOSE:
# Manage and protect the existing GCS bucket used by Terraform
# as the remote backend for this environment.
#
# WHY:
# - Enable object versioning for Terraform state recovery.
# - Automatically clean old noncurrent state versions after 30 days.
# - Prevent accidental deletion of the backend bucket from Terraform.
#
# NOTE:
# This bucket already exists, so import it before terraform plan/apply.
# ==========================================================
resource "google_storage_bucket" "tfstate" {
  name     = "project-19d98bfe-795f-49b8-af0-tfstate"
  location = "US-CENTRAL1"

  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  labels = {
    environment = "dev"
    managed_by  = "terraform"
    purpose     = "tfstate"
    project     = "microservices-demo"
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age        = 30
      with_state = "ARCHIVED"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
