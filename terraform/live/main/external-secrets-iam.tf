resource "google_service_account_iam_member" "external_secrets_argocd_workload_identity" {
  service_account_id = module.external_secrets_gsm_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[argocd/argocd-external-secrets]"

  depends_on = [module.external_secrets_gsm_sa]
}

resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = module.external_secrets_gsm_sa.member

  depends_on = [module.external_secrets_gsm_sa]
}
