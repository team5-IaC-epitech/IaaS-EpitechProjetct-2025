# Reserve an IP address range for private service connection
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.vpc_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
  project       = var.project_id

  depends_on = [google_project_service.required_apis]
}

# Create a private VPC connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  depends_on = [google_project_service.required_apis]
}

# Reserve global static IP for ingress load balancer
resource "google_compute_global_address" "ingress" {
  name         = "${var.app_name}-ingress-ip-${var.environment}"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  depends_on = [google_project_service.required_apis]
}
