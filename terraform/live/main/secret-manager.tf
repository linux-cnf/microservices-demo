# External Secrets Operator uses this Google service account
# through GKE Workload Identity to read secrets from Secret Manager.
module "external_secrets_gsm_sa" {
  source = "../../modules/service-account"

  gcp_project_id = var.gcp_project_id
  account_id     = "external-secrets-gsm"
  display_name   = "External Secrets Google Secret Manager"

  depends_on = [module.project_services]
}

# Secret metadata is managed by Terraform.
# Secret value/version is NOT managed by Terraform to avoid storing
# the Slack bot token in Terraform state.
#
# IMPORTANT:
# The secret value should be added manually using:
# gcloud secrets versions add argocd-slack-bot-token --data-file=-
#
# If this long-lived secret survives terraform destroy, import it before plan/apply:
# terraform import google_secret_manager_secret.argocd_slack_bot_token \
#   projects/<PROJECT_ID>/secrets/argocd-slack-bot-token
resource "google_secret_manager_secret" "argocd_slack_bot_token" {
  project   = var.gcp_project_id
  secret_id = "argocd-slack-bot-token"

  replication {
    auto {}
  }

  depends_on = [module.project_services]
}

# Allow only the External Secrets GCP service account to read the Slack token.
resource "google_secret_manager_secret_iam_member" "argocd_slack_token_external_secrets" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.argocd_slack_bot_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.external_secrets_gsm_sa.member

  depends_on = [
    google_secret_manager_secret.argocd_slack_bot_token,
    module.external_secrets_gsm_sa
  ]
}

# Allow Kubernetes service account external-secrets/external-secrets
# to impersonate the GCP service account using Workload Identity.
resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  service_account_id = module.external_secrets_gsm_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[external-secrets/external-secrets]"

  depends_on = [module.external_secrets_gsm_sa]
}
