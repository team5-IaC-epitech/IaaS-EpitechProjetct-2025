resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "${var.vpc_name}-subnet"
  ip_cidr_range = var.cidr_block
  network       = google_compute_network.vpc_network.id
  region        = var.region

  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.8.0.0/20"
  }
}
