# -------------------------------------------------------------------
# PURPOSE:
# Defines reusable inputs for GitHub owner, repository, environments,
# and approval reviewers.
# -------------------------------------------------------------------

variable "github_owner" {
  type        = string
  description = "GitHub organization or user owner."
  default     = "linux-cnf"
}

variable "repository_name" {
  type        = string
  description = "GitHub repository name."
  default     = "microservices-demo"
}

variable "destroy_environment_name" {
  type        = string
  description = "Protected environment for destructive workflows."
  default     = "production-destroy"
}

variable "destroy_reviewer_username" {
  type        = string
  description = "GitHub username allowed to approve destroy workflow."
  default     = "linux-cnf"
}
