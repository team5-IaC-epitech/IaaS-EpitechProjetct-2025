output "vpc_id" {
  value = google_compute_network.vpc_network.id
}

output "public_subnet_id" {
  value = google_compute_subnetwork.public_subnet.id
}

output "private_subnet_id" {
  value = google_compute_subnetwork.private_subnet.id
}

# output "cluster_name" {
#   value       = google_container_cluster.primary.name
#   description = "The name of the GKE cluster"
# }

# output "cluster_endpoint" {
#   value       = google_container_cluster.primary.endpoint
#   description = "The endpoint of the GKE cluster"
#   sensitive   = true
# }

# output "cluster_ca_certificate" {
#   value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
#   description = "The CA certificate of the GKE cluster"
#   sensitive   = true
# }

# output "kubectl_config_command" {
#   value = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
# }
