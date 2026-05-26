resource "google_service_account_iam_member" "external_secrets_argocd_workload_identity" {
  service_account_id = "projects/project-9e0b2bd9-4649-487c-9d1/serviceAccounts/external-secrets-gsm@project-9e0b2bd9-4649-487c-9d1.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:project-9e0b2bd9-4649-487c-9d1.svc.id.goog[argocd/argocd-external-secrets]"
}

resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = "project-9e0b2bd9-4649-487c-9d1"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:external-secrets-gsm@project-9e0b2bd9-4649-487c-9d1.iam.gserviceaccount.com"
}
