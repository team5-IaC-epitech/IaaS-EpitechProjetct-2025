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

output "kubectl_config_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  description = "Command to configure kubectl"
}

# Cloud SQL outputs
output "cloudsql_instance_name" {
  value       = google_sql_database_instance.postgres.name
  description = "Cloud SQL instance name"
}

output "cloudsql_private_ip" {
  value       = google_sql_database_instance.postgres.private_ip_address
  description = "Cloud SQL private IP address"
  sensitive   = true
}

output "cloudsql_connection_name" {
  value       = google_sql_database_instance.postgres.connection_name
  description = "Cloud SQL connection name"
}

# Artifact Registry outputs
output "artifact_registry_url" {
  value       = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
  description = "Artifact Registry URL for Docker images"
}

# Secret Manager outputs
output "secret_manager_database_url_name" {
  value       = google_secret_manager_secret.database_url.secret_id
  description = "Secret Manager secret name for DATABASE_URL"
}

output "secret_manager_jwt_secret_name" {
  value       = google_secret_manager_secret.jwt_secret.secret_id
  description = "Secret Manager secret name for JWT_SECRET"
}

# Workload Identity outputs
output "gke_workload_sa_email" {
  value       = google_service_account.gke_workload.email
  description = "GKE workload identity service account email"
}

# Ingress outputs
output "ingress_ip" {
  value       = google_compute_global_address.ingress.address
  description = "Static IP address for the ingress load balancer"
}

output "ingress_ip_name" {
  value       = google_compute_global_address.ingress.name
  description = "Name of the static IP resource for ingress"
}
