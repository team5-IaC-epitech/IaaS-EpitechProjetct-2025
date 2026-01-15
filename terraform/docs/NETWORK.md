# Network (VPC) Documentation

## Overview

The network module provisions a custom VPC on GCP, with isolated subnets for applications, database, and public resources. It includes NAT management, Cloud SQL peering, and restrictive firewall rules.

## Architecture

- **Custom VPC** (regional mode, no auto subnetworks)
- **Subnets:**
  - Public (internet access)
  - GKE (applications)
  - Database (Cloud SQL)
  - Secondary ranges for GKE pods/services
- **Cloud NAT** for outbound access from private resources
- **Peering** with Service Networking for Cloud SQL (import/export custom routes)
- **Firewall:**
  - Allows internal traffic (all subnets + Cloud SQL range)
  - Public HTTPS (TCP 443)
  - Google health-checks
  - Default deny all

## Main Variables

- `project_id`, `region`, `network_name`
- CIDR for each subnet and secondary ranges

## Main Outputs

- IDs and names of networks/subnets
- Secondary ranges for pods/services
- NAT and router names

## Best Practices

- Non-overlapping CIDRs, plan for growth
- Firewall: principle of least privilege
- Flow logs enabled for audit

## Usage Example

```hcl
module "network" {
  source = "../../modules/network"
  project_id = var.project_id
  region = var.region
  network_name = "epitech-vpc"
  # ...other variables
}
```
