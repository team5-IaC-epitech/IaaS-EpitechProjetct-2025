# Kubernetes (GKE) Documentation

## Overview

The Kubernetes module deploys a private GKE cluster with two node pools: one for applications, one for CI/CD runners. It applies best practices for security, autoscaling, and observability.

## Architecture

- **Private cluster** (nodes have no public IP)
- **Node pools:**
  - Application: e2-medium, autoscaling 2-10 nodes
  - Runners: e2-standard-4, autoscaling 1-5 nodes, taints for CI/CD
- **Workload Identity** enabled
- **Addons:** HPA, Network Policy, Managed Prometheus
- **Maintenance:** auto-upgrade, auto-repair, rolling update

## Security

- Shielded nodes, GKE metadata, legacy endpoints disabled
- Strict network rules (see network module)

## Main Variables

- `project_id`, `region`, `cluster_name`, `network_name`, `subnet_name`, `pods_range_name`, `services_range_name`
- Pool parameters (min/max, machine type)

## Main Outputs

- Cluster name, endpoint, CA certificate
- GKE service account email

## Usage Example

```hcl
module "kubernetes" {
  source = "../../modules/kubernetes"
  project_id = var.project_id
  region = var.region
  cluster_name = "epitech-gke-cluster"
  # ...other variables
  depends_on = [module.network]
}
```
