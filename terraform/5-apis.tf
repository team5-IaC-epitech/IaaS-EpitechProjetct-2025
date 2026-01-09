# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",           # VPC, GKE (already enabled)
    "container.googleapis.com",         # GKE (already enabled)
    "sqladmin.googleapis.com",          # Cloud SQL
    "servicenetworking.googleapis.com", # Service Networking for Private IP
    "secretmanager.googleapis.com",     # Secret Manager
    "artifactregistry.googleapis.com",  # Artifact Registry
    "cloudbuild.googleapis.com",        # Cloud Build
    "iam.googleapis.com",               # IAM for service accounts
  ])

  project = var.project_id
  service = each.key

  disable_on_destroy = false
}
