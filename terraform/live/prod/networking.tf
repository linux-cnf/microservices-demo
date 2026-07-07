module "vpc" {
  source = "../../modules/vpc"

  project_id = var.gcp_project_id
  region     = var.region

  network_name = "vpc-kfounding-prod"
  subnet_name  = "subnet-us-central1-prod"

  node_cidr    = "10.10.0.0/20"
  pod_cidr     = "10.20.0.0/18"
  service_cidr = "10.30.0.0/22"

  pod_range_name     = "pods-us-central1-prod"
  service_range_name = "services-us-central1-prod"

  depends_on = [module.project_services]
}

# NOTE:
# Cloud NAT is currently enabled mainly to provide outbound internet access
# for private GKE nodes so Argo CD can fetch external Git repositories/images.
# This keeps nodes private (no public IPs) while still allowing controlled egress.
module "cloud_nat" {
  source = "../../modules/cloud-nat"

  project_id        = var.gcp_project_id
  region            = var.region
  network_self_link = module.vpc.network_self_link

  router_name = "router-kfounding-prod"
  nat_name    = "nat-kfounding-prod"

  depends_on = [
    module.project_services,
    module.vpc
  ]
}
