# Build and push Docker image to Artifact Registry
resource "null_resource" "build_and_push_image" {
  # Trigger rebuild when app code changes
  triggers = {
    dockerfile_hash = filesha256("${path.module}/../app/Dockerfile")
  }

  # Build and push image using Cloud Build
  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    interpreter = ["PowerShell", "-Command"]
    command     = "gcloud builds submit --config=cloudbuild.yaml --substitutions=\"_ARTIFACT_REGISTRY_URL=${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id},SHORT_SHA=terraform\" --project=${var.project_id} ."
  }

  depends_on = [
    google_artifact_registry_repository.docker_repo,
    google_artifact_registry_repository_iam_member.gke_nodes_pull,
    google_project_iam_member.cloudbuild_artifactregistry
  ]
}

# Output for verification
output "image_url" {
  description = "Full Docker image URL"
  value       = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}/${var.app_name}:latest"
}