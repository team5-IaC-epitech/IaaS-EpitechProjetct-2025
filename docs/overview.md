# Project Overview

Task Manager is a task management API developed in Go, deployed on Google Kubernetes Engine (GKE) and orchestrated via Helm. The infrastructure is managed with Terraform to ensure reproducibility and scalability.

## Architecture

- **Backend**: REST API in Go (Gin framework)
- **Database**: PostgreSQL (Cloud SQL)
- **Deployment**: Docker, Helm, GKE
- **Infrastructure as Code**: Terraform
- **Scalability**: Horizontal Pod Autoscaler (HPA) configured

## Main Features

- Create, update, delete, and view tasks
- JWT authentication
- Basic observability (logs, readiness/liveness probes)
- Automated database migration

## Project Structure

- `app/`: API source code, Dockerfile, Go configuration
- `helm/`: Helm chart for Kubernetes deployment
- `terraform/`: Infrastructure scripts (network, GKE, Cloud SQL, etc.)
- `scripts/`: Tools for load testing and automation

For more details, see the following sections.
