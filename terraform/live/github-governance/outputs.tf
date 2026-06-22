# -------------------------------------------------------------------
# PURPOSE:
# Exposes important GitHub governance resource details after apply.
# Useful for verification, audit, and troubleshooting.
# -------------------------------------------------------------------
output "production_destroy_environment" {
  value = github_repository_environment.production_destroy.environment
}

output "destroy_reviewer_user_id" {
  value = data.github_user.destroy_reviewer.id
}
