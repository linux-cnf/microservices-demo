# -------------------------------------------------------------------
# PURPOSE:
# Looks up GitHub users required for environment protection reviewers.
# Converts GitHub usernames into numeric user IDs required by Terraform.
# -------------------------------------------------------------------
data "github_user" "destroy_reviewer" {
  username = var.destroy_reviewer_username
}
