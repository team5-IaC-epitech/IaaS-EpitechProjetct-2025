resource "google_container_cluster" "primary" {
  name = var.cluster_name
  location = var.region
  network = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.private_subnet.id
  enable_autopilot = true

  ip_allocation_policy {
    cluster_secondary_range_name = "pods-range"
    services_secondary_range_name = "services-range"
  }
  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }
  deletion_protection = false
}

resource "google_service_account" "gke_nodes" {
  account_id   = substr("${var.cluster_name}-nodes", 0, 30)
  display_name = "GKE Nodes Service Account"
  project      = var.project_id
}