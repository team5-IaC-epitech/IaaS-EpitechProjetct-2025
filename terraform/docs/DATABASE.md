# Database (Cloud SQL) Documentation

## Overview

The Database module provisions a highly available Cloud SQL PostgreSQL instance, accessible only via private IP, with secure credential management via Secret Manager.

## Architecture

- **Cloud SQL PostgreSQL 15 instance** (regional mode, HA)
- **Private access** (no public IP)
- **Automated backups** and point-in-time recovery
- **Password generated and stored in Secret Manager**
- **Connection via VPC peering**

## Security

- Access restricted to GKE range via firewall
- Secret Manager: only the application service account can read the password
- Workload Identity for application access

## Main Variables

- `project_id`, `region`, `instance_name`, `network_id`, `gke_service_account_email`, `gke_subnet_cidr`, `private_vpc_connection`
- Parameters: DB name, user, tier, disk size

## Main Outputs

- Instance name, private IP, DB name, user, secret ID

## Usage Example

```hcl
module "database" {
  source = "../../modules/database"
  project_id = var.project_id
  region = var.region
  instance_name = "epitech-postgres"
  # ...other variables
  depends_on = [module.network, module.kubernetes]
}
```
