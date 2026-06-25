resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.gcp_project_id
  location      = var.region
  repository_id = var.repository_id
  format        = var.format

  description = "Docker repository for microservices-demo images"

  cleanup_policy_dry_run = var.cleanup_policy_dry_run

  dynamic "cleanup_policies" {
    for_each = var.cleanup_policies

    content {
      id     = cleanup_policies.value.id
      action = cleanup_policies.value.action

      dynamic "condition" {
        for_each = lookup(cleanup_policies.value, "condition", null) == null ? [] : [cleanup_policies.value.condition]

        content {
          tag_state  = lookup(condition.value, "tag_state", null)
          older_than = lookup(condition.value, "older_than", null)
        }
      }

      dynamic "most_recent_versions" {
        for_each = lookup(cleanup_policies.value, "most_recent_versions", null) == null ? [] : [cleanup_policies.value.most_recent_versions]

        content {
          keep_count = most_recent_versions.value.keep_count
        }
      }
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}
