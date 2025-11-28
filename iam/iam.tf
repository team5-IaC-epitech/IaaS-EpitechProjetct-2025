terraform {

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.12.0"
    }
  }

  backend "gcs" {
  }

}

resource "google_project_iam_member" "teachers" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "user:jeremie@jjaouen.com"
}

resource "google_project_iam_member" "students" {
  for_each = toset([
    "valentin.maurel7@gmail.com",
    "enzo.pfeiffer@outlook.fr",
    "lj.stan92@gmail.com",
    "axel.derbisz@gmail.com",
    "markobinoshii@gmail.com"
  ])
  project = var.project_id
  role    = "roles/editor"
  member  = "user:${each.value}"
}