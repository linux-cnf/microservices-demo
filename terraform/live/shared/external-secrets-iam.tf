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

# Allow Kubernetes service account ai/argocd-external-secrets
# to impersonate the GCP service account using Workload Identity.
resource "google_service_account_iam_member" "external_secrets_ai_workload_identity" {
  service_account_id = module.external_secrets_gsm_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[ai/argocd-external-secrets]"

  depends_on = [module.external_secrets_gsm_sa]
}

# Dev Argo CD External Secrets Workload Identity binding.
# Allows the Kubernetes service account argocd-dev/argocd-external-secrets
# to impersonate the Google service account external-secrets-gsm.
resource "google_service_account_iam_member" "external_secrets_argocd_dev_workload_identity" {
  service_account_id = module.external_secrets_gsm_sa.name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${var.gcp_project_id}.svc.id.goog[argocd-dev/argocd-external-secrets]"
}
