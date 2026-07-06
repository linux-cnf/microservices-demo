# -------------------------------------------------------------------
# PURPOSE:
# Defines input variables for the reusable GKE node pool module.
#
# RESPONSIBILITIES:
# - Allow each environment to configure node pool name, size, zones,
#   labels, taints, machine type, disk, autoscaling, and service account.
#
# WHY THIS EXISTS?
# Dev and prod can reuse the same node pool module while passing
# different values from terraform/live/<env>.
# -------------------------------------------------------------------
variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the GKE node pool will be created"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster"
}

variable "location" {
  type        = string
  description = "Location of the GKE cluster where the node pool will be created"
}

variable "node_pool_name" {
  type        = string
  description = "Name of the GKE node pool"
  default     = "primary-node-pool"
}

variable "machine_type" {
  type        = string
  description = "Machine type for GKE nodes"
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  type        = number
  description = "Disk size in GB for each node"
  default     = 30
}

variable "disk_type" {
  type        = string
  description = "Disk type for each node"
  default     = "pd-standard"
}

variable "image_type" {
  type        = string
  description = "Image type for GKE nodes"
  default     = "COS_CONTAINERD"
}

variable "max_pods_per_node" {
  type        = number
  description = "Maximum number of pods per node"
  default     = 64
}

variable "node_labels" {
  type        = map(string)
  description = "Kubernetes node labels to apply to all nodes in this pool"
  default     = {}
}

variable "node_taints" {
  description = "Kubernetes node taints to apply to all nodes in this pool"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "service_account" {
  type        = string
  description = "Service account used by GKE nodes"
  default     = null
}

variable "oauth_scopes" {
  type        = list(string)
  description = "OAuth scopes for GKE nodes"
  default = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

#Multi-zone cluster settings
variable "node_locations" {
  type        = list(string)
  description = "Zones where this node pool can create nodes"
  default     = []
}

variable "initial_node_count" {
  type        = number
  description = "Initial number of nodes per zone during node pool creation"
  default     = 1
}

variable "total_min_node_count" {
  type        = number
  description = "Total minimum nodes across all zones"
  default     = 1
}

variable "total_max_node_count" {
  type        = number
  description = "Total maximum nodes across all zones"
  default     = 3
}

variable "location_policy" {
  type        = string
  description = "Autoscaling location policy"
  default     = "BALANCED"

  validation {
    condition     = contains(["BALANCED", "ANY"], var.location_policy)
    error_message = "location_policy must be either BALANCED or ANY."
  }
}
