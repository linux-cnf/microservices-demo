output "role" {
  description = "IAM role applied"
  value       = google_project_iam_member.binding.role
}

output "member" {
  description = "IAM member receiving the role"
  value       = google_project_iam_member.binding.member
}
