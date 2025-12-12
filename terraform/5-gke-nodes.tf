resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      environment = var.environment
      node_pool   = "primary"
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
  count      = var.create_system_node_pool ? 1 : 0
  name       = "system-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    preemptible  = false
    machine_type = "e2-medium"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      environment = var.environment
      node_pool   = "system"
    }
    tags = ["gke-node", "${var.cluster_name}", "system"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
    workload_metadata_config {
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
