terraform {

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }

  backend "gcs" {
  }

}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "vpc_network" {
  name = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "${var.vpc_name}-subnet"
  ip_cidr_range = var.cidr_block
  network       = google_compute_network.vpc_network.id
  region        = var.region

  secondary_ip_range {
  range_name    = "pods-range"
  ip_cidr_range = "10.1.0.0/16"
}

  secondary_ip_range {
    range_name = "services-range"
    ip_cidr_range = "10.2.0.0/16"
  }
}

resource "google_container_cluster "primary" {
  name = var.cluster_name
  location = var.region
  remove_default_node_pool = true
  initial_node_count = 1

  network = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.vpc_subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name = "pods-range"
    services_secondary_range_name = "services-range"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  realease_channel {
    channel = "REGULAR"
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  addons_config {
    http_load_balancinf {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
  }
}

  network_policy {
      enabled = true
  }
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus_config {
      enabled = true
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name = "primary-node-pool"
  location = var.region
  cluster = google_container_cluster.primary.name
  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    preemptible = var.preemptible
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      environment = var.environment
      node_pool = "primary"
    }
    tags = ["gke-node", "${var.cluster_name}"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
  }

    management {
      auto_repair  = true
      auto_upgrade = true
    }
    upgrade_settings {
      max_surge       = 1
      max_unavailable = 0
    }
  }

  resource "google_container_node_pool" "system_nodes" {
    count = var.create_system_node_pool ? 1 : 0
    name = "system-node-pool"
    location = var.region
    cluster = google_container_cluster.primary.name
    node_count = 1

    autoscaling {
      min_node_count = 1
      max_node_count = 2
    }

    node_config {
      preemptible = false
      machine_type = "e2-small"

      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
      labels = {
        environment = var.environment
        node_pool = "system"
      }
      tags = ["gke-node", "${var.cluster_name}", "system"]

      metadata = {
        disable-legacy-endpoints = "true"
      }
      workload_identity_config {
        mode = "GKE_METADATA"
      }

      taint {
        key    = "workload-type"
        value  = "system"
        effect = "NO_SCHEDULE"
      }
    }
    management {
      auto_repair  = true
      auto_upgrade = true
    }
  }


output "vpc_id" {
  value = google_compute_network.vpc_network.id
}

output "subnet_id" {
  value = google_compute_subnetwork.vpc_subnet.id
}

output "cluster_name" {
  value = google_container_cluster.primary.name
  description = "The name of the GKE cluster"
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
  description = "The endpoint of the GKE cluster"
  sensitive = true
}

output "cluster_ca_certificate" {
  value = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  description = "The CA certificate of the GKE cluster"
  sensitive = true
}

output "kubectl_config_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}
