resource "google_service_account" "gke_nodes" {
  account_id   = substr("${var.cluster_name}-nodes", 0, 30)
  display_name = "GKE Nodes Service Account"
  project      = var.project_id
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc_name
  subnetwork = "${var.vpc_name}-subnet"

  node_config {
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "PROVIDER_UNSPECIFIED"
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  enable_shielded_nodes = true
  enable_legacy_abac    = false

  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  release_channel {
    channel = "REGULAR"
  }

  depends_on = [
    google_service_account.gke_nodes
  ]
}

resource "google_container_node_pool" "application_pool" {
  name     = "app-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = var.app_pool_min_nodes
    max_node_count = var.app_pool_max_nodes
  }

  node_config {
    machine_type = var.app_pool_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      pool        = "application"
      environment = var.environment
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
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

resource "google_container_node_pool" "runners_pool" {
  name     = "runners-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = var.runners_pool_min_nodes
    max_node_count = var.runners_pool_max_nodes
  }

  node_config {
    machine_type = var.runners_pool_machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      pool        = "runners"
      environment = var.environment
    }

    taint {
      key    = "workload"
      value  = "github-runner"
      effect = "NO_SCHEDULE"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
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