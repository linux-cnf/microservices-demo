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

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes in the node pool"
  default     = 1
}

variable "max_node_count" {
  type        = number
  description = "Maximum number of nodes in the node pool"
  default     = 2
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
