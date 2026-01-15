# IAM & Workload Identity Documentation

## Overview

The IAM module configures keyless authentication for GitHub Actions and Kubernetes workloads via Workload Identity Federation. It manages service accounts and minimal required permissions.

## Architecture

- **Workload Identity Pool** for GitHub Actions (OIDC)
- **Provider** restricted to the target GitHub repo
- **CI/CD service account** with rights: GKE, Artifact Registry, impersonation
- **Application service account** for GKE (Cloud SQL, Secret Manager, logs, metrics)
- **Bindings**: each service account is linked to its usage (GitHub or GKE pods)

## Security

- No long-lived keys
- Minimal permissions (principle of least privilege)
- GitHub access limited to repo/org

## Main Variables

- `project_id`, `github_organization`, `github_repository`, `app_name`, `k8s_namespace`, `k8s_service_account_name`
- Role lists for each service account

## Main Outputs

- OIDC provider, service account emails

## Usage Example

```hcl
module "iam" {
  source = "../../modules/iam"
  project_id = var.project_id
  github_organization = "<org>"
  github_repository = "<repo>"
  # ...other variables
  depends_on = [module.kubernetes]
}
```
