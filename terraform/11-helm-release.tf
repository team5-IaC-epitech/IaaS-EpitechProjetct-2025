# Deploy task-manager via Helm
resource "helm_release" "task_manager" {
  name      = var.app_name
  chart     = "../helm/${var.app_name}"
  namespace = "default"

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes

  # Override values using set blocks
  set {
    name  = "image.repository"
    value = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}/${var.app_name}"
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "gcp.projectId"
    value = var.project_id
  }

  set {
    name  = "gcp.workloadIdentityServiceAccount"
    value = google_service_account.gke_workload.email
  }

  set {
    name  = "secrets.databaseUrlSecretName"
    value = google_secret_manager_secret.database_url.secret_id
  }

  set {
    name  = "secrets.jwtSecretSecretName"
    value = google_secret_manager_secret.jwt_secret.secret_id
  }

  depends_on = [
    google_container_cluster.primary,
    google_sql_database_instance.postgres,
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_version.jwt_secret,
    google_service_account_iam_member.workload_identity_binding
  ]
}
