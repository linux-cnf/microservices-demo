resource "google_service_account_iam_member" "external_secrets_argocd_workload_identity" {
  service_account_id = "projects/project-19d98bfe-795f-49b8-af0/serviceAccounts/external-secrets-gsm@project-19d98bfe-795f-49b8-af0.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:project-19d98bfe-795f-49b8-af0.svc.id.goog[argocd/argocd-external-secrets]"
}

resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = "project-19d98bfe-795f-49b8-af0"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:external-secrets-gsm@project-19d98bfe-795f-49b8-af0.iam.gserviceaccount.com"
}
