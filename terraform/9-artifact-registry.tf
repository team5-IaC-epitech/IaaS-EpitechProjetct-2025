# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "${var.app_name}-${var.environment}"
  format        = "DOCKER"
  project       = var.project_id

  description = "Docker repository for ${var.app_name} application (${var.environment})"

  depends_on = [google_project_service.required_apis]
}

# Grant GKE nodes permission to pull images
resource "google_artifact_registry_repository_iam_member" "gke_nodes_pull" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
  project    = var.project_id
}

# Get project number for Cloud Build service account
data "google_project" "project" {
  project_id = var.project_id
}

# Grant Cloud Build permission to push images
resource "google_project_iam_member" "cloudbuild_artifactregistry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"

  depends_on = [google_project_service.required_apis]
}

# Grant GitHub Actions service account permission to submit Cloud Build jobs
# This is needed for the CI/CD pipeline to build Docker images
resource "google_project_iam_member" "github_actions_cloudbuild" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:team5-sa-${var.environment}@${var.project_id}.iam.gserviceaccount.com"
}

# Grant GitHub Actions service account permission to use service account
resource "google_project_iam_member" "github_actions_service_usage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:team5-sa-${var.environment}@${var.project_id}.iam.gserviceaccount.com"
}
