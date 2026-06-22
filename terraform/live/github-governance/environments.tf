# -------------------------------------------------------------------
# PURPOSE:
# Creates protected GitHub environments for sensitive workflows.
# Used to gate destructive actions such as full platform teardown.
# -------------------------------------------------------------------
resource "github_repository_environment" "production_destroy" {
  repository  = var.repository_name
  environment = var.destroy_environment_name

  reviewers {
    users = [data.github_user.destroy_reviewer.id]
  }

  prevent_self_review = false
}
