resource "google_storage_bucket" "tfstate" {
  name                        = var.tfstate_bucket_name
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age        = 90
      with_state = "ARCHIVED"
    }

    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                = 30
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }

    action {
      type = "Delete"
    }
  }

  labels = {
    purpose     = "terraform-state"
    managed_by  = "terraform-bootstrap"
    environment = "shared"
  }

  lifecycle {
    prevent_destroy = true
  }
}
