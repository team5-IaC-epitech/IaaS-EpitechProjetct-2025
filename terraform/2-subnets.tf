resource "google_compute_subnetwork" "public_subnet" {
  name                     = var.nat_subnet_name
  ip_cidr_range            = "10.0.0.0/24"
  network                  = google_compute_network.vpc_network.id
  region                   = var.region
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = var.gke_subnet_name
  ip_cidr_range            = "10.0.1.0/24"
  network                  = google_compute_network.vpc_network.id
  region                   = var.region
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.8.0.0/20"
  }
}
