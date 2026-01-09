# Generate JWT secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = false # Base64-compatible
}

# Create Secret Manager secrets
resource "google_secret_manager_secret" "database_url" {
  secret_id = "${var.app_name}-database-url-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${var.app_name}-jwt-secret-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

# Store secret versions
resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id

  # Format: postgres://user:pass@host:5432/db?sslmode=require
  # URL-encode the password to handle special characters
  secret_data = "postgres://${google_sql_user.db_user.name}:${urlencode(random_password.db_password.result)}@${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.database.name}?sslmode=require"
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}

# Create GKE service account for workload identity
resource "google_service_account" "gke_workload" {
  account_id   = substr("${var.cluster_name}-app-${var.environment}", 0, 30)
  display_name = "GKE Workload Identity for Task Manager"
  project      = var.project_id
}

# Grant GKE service account access to secrets
resource "google_secret_manager_secret_iam_member" "database_url_access" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gke_workload.email}"
}

resource "google_secret_manager_secret_iam_member" "jwt_secret_access" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gke_workload.email}"
}

# Bind Kubernetes service account to GCP service account (Workload Identity)
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.gke_workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/${var.app_name}]"
}
