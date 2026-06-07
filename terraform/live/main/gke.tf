module "gke_cluster" {
  source              = "../../modules/gke-cluster"
  gcp_project_id      = var.gcp_project_id
  name                = var.name
  zone                = var.zone
  region              = var.region
  deletion_protection = false

  network    = module.vpc.network_self_link
  subnetwork = module.vpc.subnet_self_link

  pod_range_name     = module.vpc.pod_range_name
  service_range_name = module.vpc.service_range_name

  datapath_provider = "ADVANCED_DATAPATH"

  enable_private_nodes    = true
  enable_private_endpoint = false
  master_ipv4_cidr_block  = "172.16.0.0/28"

  master_authorized_networks = [
    {
      cidr_block   = "163.227.186.128/30"
      display_name = "on-prem-bastion"
    }
  ]

  node_locations = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c"
  ]

  depends_on = [
    module.project_services,
    module.vpc
  ]
}

# Regional primary node pool.
# Uses total autoscaling across zones:
# min 1 node total, max 3 nodes total across us-central1-a/b/c.
module "gke_node_pool" {
  source         = "../../modules/gke-node-pool"
  gcp_project_id = var.gcp_project_id
  cluster_name   = module.gke_cluster.cluster_name
  location       = var.region

  node_locations = [
    "us-central1-a",
    "us-central1-b",
    "us-central1-c"
  ]

  initial_node_count   = 1
  total_min_node_count = 1
  total_max_node_count = 3
  location_policy      = "BALANCED"
  node_pool_name       = "primary-node-pool"
  machine_type         = "e2-standard-2"
  disk_size_gb         = 30
  disk_type            = "pd-standard"
  image_type           = "COS_CONTAINERD"
  max_pods_per_node    = 64

  depends_on = [module.gke_cluster]
}

# Observability pool intentionally restricted to us-central1-a
# because it runs stateful/PVC-backed platform workloads.
module "gke_node_pool_platform_observability" {
  source         = "../../modules/gke-node-pool"
  gcp_project_id = var.gcp_project_id
  cluster_name   = module.gke_cluster.cluster_name
  location       = var.region

  node_locations = [
    "us-central1-a"
  ]

  initial_node_count   = 1
  node_pool_name       = "platform-observability"
  machine_type         = "e2-highmem-2"
  disk_size_gb         = 30
  disk_type            = "pd-standard"
  image_type           = "COS_CONTAINERD"
  total_min_node_count = 1
  total_max_node_count = 2
  location_policy      = "BALANCED"

  max_pods_per_node = 64

  node_labels = {
    workload = "observability"
    tier     = "platform"
  }

  node_taints = [
    {
      key    = "dedicated"
      value  = "observability"
      effect = "NO_SCHEDULE"
    }
  ]

  depends_on = [module.gke_cluster]
}
