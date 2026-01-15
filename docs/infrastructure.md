# Infrastructure & Deployment

This document describes the infrastructure and deployment steps for Task Manager on Google Cloud Platform.

## Main Components

- **Google Kubernetes Engine (GKE)**: Regional, multi-zone cluster with autoscaling enabled
- **Cloud SQL (PostgreSQL)**: Managed instance, private access, automatic backups
- **VPC**: Private network with dedicated subnets for nodes and database
- **Artifact Registry**: Docker image storage

## Provisioning

The infrastructure is declared in the `terraform/` folder and deployed with:

```bash
gcloud auth login
cd terraform
terraform init
terraform plan -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars
```

## Application Deployment

1. **Build the image:**
   ```bash
   cd app
   docker build -t <REGISTRY>/task-manager:latest .
   docker push <REGISTRY>/task-manager:latest
   ```
2. **Helm deployment:**
   ```bash
   cd helm/task-manager
   helm upgrade --install task-manager . --namespace task-manager --create-namespace
   ```

## Security

- Secrets stored in Google Secret Manager and injected via CSI
- Access restricted by Workload Identity

## Observability

- HTTP probes for pod health
- Logs accessible via `kubectl logs` and Cloud Logging

For more configuration details, see the files in `terraform/` and `helm/`.
