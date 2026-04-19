output "email" {
  description = "Email of the service account"
  value       = google_service_account.service_account.email
}

output "name" {
  description = "Fully-qualified name of the service account"
  value       = google_service_account.service_account.name
}

output "member" {
  description = "IAM member string for the service account"
  value       = "serviceAccount:${google_service_account.service_account.email}"
}
