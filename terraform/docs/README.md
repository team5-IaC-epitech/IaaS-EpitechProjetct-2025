# Task Manager Infrastructure Documentation

This folder describes the actual infrastructure deployed for the Task Manager project on GCP, based on the repository's Terraform code.

## Architecture Overview

The infrastructure includes:

- **Custom VPC** named `team5-vpc-dev` (by default), no auto subnetworks, regional routing
- **Subnets**:
  - Public: `team5-nat-subnet-dev` (10.0.0.0/24)
  - Private (GKE): `team5-gke-subnet-dev` (10.0.1.0/24) with secondary ranges for pods (10.4.0.0/14) and services (10.8.0.0/20)
- **Cloud NAT** and **router** for outbound access from private resources
- **GKE cluster** (Autopilot, private, Workload Identity enabled, native secret manager)
- **Cloud SQL PostgreSQL** (version 16, HA in prod, private IP only, backups, optimized flags)
- **Secret Manager** for storing DB and JWT credentials
- **Artifact Registry** for Docker images
- **App deployment via Helm** (chart in helm/task-manager)
- **IAM**: service accounts for GKE, secret access, CI/CD, Workload Identity for pods

## Folder Structure

```
terraform/
├── 0-providers.tf
├── 1-vpc.tf
├── 2-subnets.tf
├── 3-nat.tf
├── 4-gke.tf
├── 5-apis.tf
├── 6-service-networking.tf
├── 7-cloudsql.tf
├── 8-secrets.tf
├── 9-artifact-registry.tf
├── 10-cloudbuild.tf
├── 11-helm-release.tf
├── outputs.tf
├── variables.tf
└── docs/
   └── README.md (this file)
```

## Prerequisites

- GCP project with billing enabled
- Terraform >= 1.5.0
- gcloud CLI configured for the project
- Permissions: Compute Admin, Kubernetes Engine Admin, Cloud SQL Admin, Service Account Admin
- GCS bucket for Terraform state

## Quick Deployment

1. Authenticate:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project iaasepitech
```

2. Initialize:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

3. Get useful outputs:

```bash
terraform output
# To configure kubectl:
terraform output -raw kubectl_config_command | bash
```

## Main Modules and Resources

- **VPC & Network**: see [NETWORK.md](./NETWORK.md)
- **GKE (Kubernetes)**: see [KUBERNETES.md](./KUBERNETES.md)
- **Cloud SQL Database**: see [DATABASE.md](./DATABASE.md)
- **Secrets & IAM**: see [IAM.md](./IAM.md)
- **Artifact Registry & CI/CD**: see [ARTIFACT.md](./ARTIFACT.md)

## Main Outputs

- `vpc_id`, `public_subnet_id`, `private_subnet_id`
- `cloudsql_instance_name`, `cloudsql_private_ip`, `cloudsql_connection_name`
- `artifact_registry_url`, `gke_workload_sa_email`
- `secret_manager_database_url_name`, `secret_manager_jwt_secret_name`
- `ingress_ip`, `ingress_ip_name`

## Project-specific Best Practices

- IP ranges are large to anticipate scaling (pods/services)
- Secrets are injected via Secret Manager and Workload Identity (no static keys)
- Images are stored in Artifact Registry, deployed via Helm
- Terraform outputs make kubectl configuration and CI/CD integration easier

---

_This documentation is generated from the actual Terraform code of the project. For any changes, refer to the `.tf` files at the root._
