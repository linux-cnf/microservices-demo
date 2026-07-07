module "artifact_registry" {
  source         = "../../modules/artifact-registry"
  gcp_project_id = var.gcp_project_id
  region         = var.region
  repository_id  = "microservices-demo"

  cleanup_policy_dry_run = true

  cleanup_policies = [
    {
      id     = "delete-older-than-14-days"
      action = "DELETE"
      condition = {
        tag_state  = "ANY"
        older_than = "1209600s"
      }
    },
    {
      id     = "keep-latest-5"
      action = "KEEP"
      most_recent_versions = {
        keep_count = 5
      }
    }
  ]
}

module "artifact_registry_platform_observability" {
  source         = "../../modules/artifact-registry"
  gcp_project_id = var.gcp_project_id
  region         = var.region
  repository_id  = "platform-observability"

  cleanup_policy_dry_run = true

  cleanup_policies = [
    {
      id     = "delete-older-than-14-days"
      action = "DELETE"
      condition = {
        tag_state  = "ANY"
        older_than = "1209600s"
      }
    },
    {
      id     = "keep-latest-3"
      action = "KEEP"
      most_recent_versions = {
        keep_count = 3
      }
    }
  ]
}

module "artifact_registry_ai_microservices" {
  source         = "../../modules/artifact-registry"
  gcp_project_id = var.gcp_project_id
  region         = var.region
  repository_id  = "ai-microservices"

  cleanup_policy_dry_run = true

  cleanup_policies = [
    {
      id     = "delete-older-than-7-days"
      action = "DELETE"
      condition = {
        tag_state  = "ANY"
        older_than = "604800s"
      }
    },
    {
      id     = "keep-latest-5"
      action = "KEEP"
      most_recent_versions = {
        keep_count = 5
      }
    }
  ]
}
