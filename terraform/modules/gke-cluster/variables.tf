variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the GKE cluster will be created"
}

variable "name" {
  type        = string
  description = "Name of the GKE cluster"
}

variable "zone" {
  type        = string
  description = "Zone where the GKE cluster will be created"
}

variable "region" {
  type        = string
  description = "Region of the GKE cluster"
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to protect the GKE cluster from accidental deletion"
  default     = false
}

variable "network" {
  type        = string
  description = "VPC network self link or name"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork self link or name"
}

variable "pod_range_name" {
  type        = string
  description = "Secondary range name for GKE pods"
}

variable "service_range_name" {
  type        = string
  description = "Secondary range name for GKE services"
}

variable "enable_private_nodes" {
  type        = bool
  description = "Whether nodes should have only private IPs"
  default     = true
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Whether the control plane should expose only private endpoint"
  default     = false
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "CIDR block for the GKE control plane private endpoint"
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to access the public GKE control plane endpoint"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "datapath_provider" {
  type        = string
  description = "GKE datapath provider. ADVANCED_DATAPATH enables Dataplane V2"
  default     = "ADVANCED_DATAPATH"
}

variable "release_channel" {
  type        = string
  description = "GKE release channel"
  default     = "REGULAR"
}
