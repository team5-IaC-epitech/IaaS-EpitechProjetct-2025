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
    range_name = "pods"
    ip_cidr_range = "10.0.2.0/24"
  }
  secondary_ip_range {
    range_name = "services"
    ip_cidr_range = "10.0.3.0/24"
  }
}

resource "google_container_cluster" "autopilot" {
  name = var.cluster_name
  location = var.region
  enable_autopilot = true
  network = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.vpc_subnet.id
  ip_allocation_policy {
    cluster_secondary_range_name = "pods"
    services_secondary_range_name = "services"
  }
  release_channel {
    channel = "REGULAR"
  }
  deletion_protection = false
}

resource "google_sql_database_instance" "dev-db" {
  name = "team5-dev-sqldb"
  region = var.region
  database_version = "SQLSERVER_2019_STANDARD"
  root_password = "team5-dev-pass"
  settings {
    tier = "db-custom-2-7680"
  }
  deletion_protection = false
}

output "vpc_id" {
  value = google_compute_network.vpc_network.id
}

output "subnet_id" {
  value = google_compute_subnetwork.vpc_subnet.id
}

output "cluster_name" {
  value = google_container_cluster.autopilot.name
}

output "endpoint" {
  value = google_container_cluster.autopilot.endpoint
}