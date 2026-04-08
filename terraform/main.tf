# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Definition of local variables
locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
  memorystore_apis = ["redis.googleapis.com"]
  cluster_name     = google_container_cluster.my_cluster.name
}

# Enable Google Cloud APIs
module "enable_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0"

  project_id                  = var.gcp_project_id
  disable_services_on_destroy = false

  # activate_apis is the set of base_apis and the APIs required by user-configured deployment options
  activate_apis = concat(local.base_apis, var.memorystore ? local.memorystore_apis : [])
}

# Create GKE cluster
resource "google_container_cluster" "my_cluster" {
  name     = var.name
  location = var.zone
  # Enable autopilot for this cluster
  #enable_autopilot = true
  release_channel {
    channel = "REGULAR"
  }
  remove_default_node_pool = true
  initial_node_count       = 1
  # Set an empty ip_allocation_policy to allow autopilot cluster to spin up correctly
  ip_allocation_policy {}
  # Avoid setting deletion_protection to false
  # until you're ready (and certain you want) to destroy the cluster.
  # Uncomment the line: "deletion_protection = false" or just run sed -i "s/# deletion_protection/deletion_protection/g" main.tf
  deletion_protection = false
  depends_on = [
    module.enable_google_apis
  ]
}

resource "google_container_node_pool" "cpu_optimized" {
  name     = "cpu-optimized"
  cluster  = google_container_cluster.my_cluster.name
  location = var.zone

  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    machine_type = "e2-standard-2"
    disk_type    = "pd-standard"
    disk_size_gb = 30

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_container_cluster.my_cluster
  ]
}

resource "google_artifact_registry_repository" "docker_repo" {
  location      = "us-central1"
  repository_id = "microservices-demo"
  description   = "Docker repository for microservices-demo images"
  format        = "DOCKER"

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    module.enable_google_apis
  ]
}
