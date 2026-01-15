# Helm Deployment

This guide explains how to deploy the Task Manager API on Kubernetes using Helm.

## Prerequisites

- Accessible Kubernetes cluster (GKE recommended)
- `kubectl` and `helm` installed and configured
- Access to a Docker registry containing the API image

## Main Steps

1. **Prepare the Docker image**

   ```bash
   cd app
   docker build -t <REGISTRY>/task-manager:latest .
   docker push <REGISTRY>/task-manager:latest
   ```

2. **Configure Helm values**

   - Edit `helm/task-manager/values.yaml` to reference the correct image repository and tag
   - Adjust environment variables and secrets if needed

3. **Deploy with Helm**

   ```bash
   cd helm/task-manager
   helm upgrade --install task-manager . --namespace task-manager --create-namespace
   ```

4. **Verify the deployment**

   ```bash
   kubectl get pods -n task-manager
   kubectl get svc -n task-manager
   ```

5. **Access the API**
   - Use the LoadBalancer IP or configured domain name

## Notes

- Autoscaling is enabled by default (see `values.yaml`)
- Secrets are injected via CSI and Google Secret Manager
- For any changes, update the values and rerun `helm upgrade`
