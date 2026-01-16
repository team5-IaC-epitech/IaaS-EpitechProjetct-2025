# GKE Standard cluster (zonal for cost optimization)
# Using Standard mode instead of Autopilot to support:
# - Privileged containers required by GitHub Actions runners (dind mode)
# - Custom node pools for workload isolation (apps vs runners)
# - More control over node configuration and scaling
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "${var.region}-a" # Zonal cluster (single zone) - cheaper than regional

  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.private_subnet.id

  # GKE Standard: remove default pool, we create custom ones below
  remove_default_node_pool = true
  initial_node_count       = 1 # Required but will be removed immediately

  # Secondary IP ranges for pods and services (VPC-native cluster)
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }

  # Private cluster: nodes have internal IPs only, master is accessible publicly
  private_cluster_config {
    enable_private_nodes    = true  # Nodes use internal IPs (more secure)
    enable_private_endpoint = false # Master accessible from internet (for CI/CD)
    master_ipv4_cidr_block  = "172.16.0.0/28" # /28 = 16 IPs for master
  }

  # Workload Identity: allows pods to use GCP service accounts securely
  # Required for Secret Manager access without storing credentials
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # GCP Managed Prometheus for monitoring metrics
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"] # Monitor k8s system components
    managed_prometheus {
      enabled = true # Use Google's managed Prometheus backend
    }
  }

  # GKE Secret Manager Add-on (native CSI driver integration)
  # Provides: secrets-store-gke.csi.k8s.io driver for SecretProviderClass
  # Requirements: GKE 1.27.14+, Workload Identity enabled
  # Docs: https://cloud.google.com/secret-manager/docs/secret-manager-managed-csi-component
  secret_manager_config {
    enabled = true
  }

  # Allow terraform destroy without manual intervention
  deletion_protection = false
}

# =============================================================================
# NODE POOL: Applications
# =============================================================================
# Dedicated pool for task-manager app, monitoring stack (Prometheus, Grafana)
resource "google_container_node_pool" "apps" {
  name     = "apps-pool"
  location = "${var.region}-a" # Same zone as cluster
  cluster  = google_container_cluster.primary.name

  # Start with 1 node, scale based on demand
  node_count = 1

  autoscaling {
    min_node_count = 1 # Always have at least 1 node for availability
    max_node_count = 3 # Cap at 3 to control costs
  }

  node_config {
    # e2-standard-2: 2 vCPU, 8GB RAM - better pod density
    # Cost: ~$49/month per node in europe-west9
    # Provides ~1200m available CPU for apps (vs ~240m on e2-medium)
    machine_type = "e2-standard-2"

    disk_size_gb = 50         # 50GB boot disk (sufficient for app containers)
    disk_type    = "pd-standard" # Standard HDD (cheaper, adequate for apps)

    # Service account for node operations (pull images, write logs)
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform" # Full GCP access via SA
    ]

    # Label for node selection in pod specs
    labels = {
      workload = "apps"
    }

    # Enable Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA" # Intercept metadata requests for Workload Identity
    }
  }

  management {
    auto_repair  = true # Automatically repair unhealthy nodes
    auto_upgrade = true # Automatically upgrade node k8s version
  }
}

# =============================================================================
# NODE POOL: GitHub Actions Runners
# =============================================================================
# Dedicated pool for self-hosted runners (requires privileged containers for dind)
# Only created when GitHub App credentials are provided
resource "google_container_node_pool" "runners" {
  count    = local.deploy_runners ? 1 : 0 # Conditional: only if credentials exist
  name     = "runners-pool"
  location = "${var.region}-a"
  cluster  = google_container_cluster.primary.name

  # Scale to zero when no jobs running (cost saving)
  autoscaling {
    min_node_count = 0 # Scale to zero when idle
    max_node_count = 3 # Max 3 concurrent runner nodes
  }

  node_config {
    # e2-standard-2: 2 vCPU, 8GB RAM - more memory for CI/CD builds
    # Runners need more resources for: npm install, docker build, tests
    machine_type = "e2-standard-2"

    disk_size_gb = 100      # 100GB for docker images and build artifacts
    disk_type    = "pd-ssd" # SSD for faster I/O during builds

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      workload = "runners"
    }

    # Taint: prevents non-runner pods from being scheduled here
    # Runners will have toleration to bypass this taint
    taint {
      key    = "workload"
      value  = "runners"
      effect = "NO_SCHEDULE" # Don't schedule pods without matching toleration
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_service_account" "gke_nodes" {
  account_id   = substr("${var.cluster_name}-nodes", 0, 30)
  display_name = "GKE Nodes Service Account"
  project      = var.project_id
}

# Grant GKE nodes necessary permissions
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}