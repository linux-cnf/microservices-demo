# =========================================================
# AI Platform Node Pool
# =========================================================
#
# This file provisions a dedicated GKE node pool for AI workloads.
# AI services such as LLM Gateway, AI Agents, vLLM, and Ollama will
# be scheduled only on this node pool using labels and taints.
#
# The node pool is isolated from application and observability
# workloads and uses regional autoscaling for high availability.
#
# =========================================================

module "gke_node_pool_ai" {
  count = var.enable_ai_node_pool ? 1 : 0

  source         = "../../modules/gke-node-pool"
  gcp_project_id = var.gcp_project_id

  cluster_name = module.gke_cluster.cluster_name
  location     = var.region

  # Keep the AI pool single-zone because initial_node_count is applied
  # per configured zone during regional node-pool creation.
  #
  # One zone ensures both AI profiles create exactly one node:
  # - cpu-small:  1 x e2-standard-2 = 2 vCPU
  # - cpu-better: 1 x e2-highmem-4  = 4 vCPU
  #
  # This is required to stay within the free-trial 12-vCPU quota.
  node_locations = [
    "us-central1-a"
  ]

  # Regional autoscaling
  initial_node_count   = 1
  total_min_node_count = var.ai_node_pool_min_count
  total_max_node_count = var.ai_node_pool_max_count

  location_policy = "BALANCED"

  # The project has a strict 12-vCPU quota.
  # Delete the old AI node before creating its replacement so switching
  # from a 2-vCPU profile to a 4-vCPU profile does not require surge quota.
  max_surge       = 0
  max_unavailable = 1

  # Node pool configuration
  node_pool_name    = "ai-node-pool"
  machine_type      = var.ai_node_pool_machine_type
  disk_size_gb      = 30
  disk_type         = "pd-standard"
  image_type        = "COS_CONTAINERD"
  max_pods_per_node = 32

  # Dedicated AI service account
  service_account = module.ai_node_pool_service_account.email

  # Node labels
  node_labels = {
    workload = "ai"
    tier     = "platform"
    purpose  = "llm"
  }

  # Node taints
  node_taints = [
    {
      key    = "workload"
      value  = "ai"
      effect = "NO_SCHEDULE"
    }
  ]

  depends_on = [
    module.gke_cluster,
    module.ai_node_pool_service_account
  ]
}
