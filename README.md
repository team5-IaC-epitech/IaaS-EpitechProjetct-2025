# Task Manager API – IaaS-EpitechProjetct-2025

## 📖 Overview

Task Manager is a REST API for task management written in Go, designed for production on Google Cloud Platform. It leverages GKE (Kubernetes), Cloud SQL (PostgreSQL), Secret Manager, Artifact Registry, and follows best practices for security and observability.

---

## ✨ Features

- RESTful API for task management (CRUD)
- JWT authentication (HS256)
- PostgreSQL storage (Cloud SQL, auto migrations)
- Observability with OpenTelemetry (OTLP)
- Native Docker & Kubernetes deployment
- Security: secrets via Secret Manager, Workload Identity
- CI/CD and images via Artifact Registry

---

## 🏗️ Architecture

- **Go + Gin** for the API
- **PostgreSQL** (Cloud SQL, private IP)
- **Kubernetes (GKE Autopilot)**, deployment via Helm
- **Secret Manager** for sensitive credentials
- **Artifact Registry** for Docker images
- **OpenTelemetry** for tracing
- **Infrastructure as Code**: Terraform

---

## 🚀 Getting Started

### Prerequisites

- Go 1.24+
- Docker
- Terraform >= 1.5
- gcloud CLI (authenticated on GCP)
- Access to a GCP project with required APIs enabled

### Installation

1. **Clone the repo:**

   ```bash
   git clone https://github.com/<your-org>/IaaS-EpitechProjetct-2025.git
   cd IaaS-EpitechProjetct-2025
   ```

2. **Set up infrastructure (Terraform):**

   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configure kubectl:**
   ```bash
   terraform output -raw kubectl_config_command | bash
   ```

### Configuration

Main environment variables for the API:

- `DATABASE_URL` (e.g.: postgres://user:pass@host:5432/db?sslmode=require)
- `JWT_HS256_SECRET` (JWT secret)
- `PORT` (default: 8080)
- `SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT` (for observability)

Secrets are automatically injected via Secret Manager and Workload Identity on GKE.

---

## 🛠️ Usage

### Development

- Run locally (requires a local PostgreSQL or Cloud SQL Proxy):

  ```bash
  go run ./app/cmd/api
  ```

- Set environment variables locally (see `.env.example` if present).

### Production

- Automated deployment via Helm on GKE (see `terraform/11-helm-release.tf`).
- Images are built and pushed to Artifact Registry via Cloud Build.

### Docker

- Local build:
  ```bash
  docker build -t task-manager:dev ./app
  ```
- Run:
  ```bash
  docker run --rm -e DATABASE_URL=... -e JWT_HS256_SECRET=... -p 8080:8080 task-manager:dev
  ```

### Kubernetes

- Deploy via Helm (chart in `helm/task-manager/`)
- Secrets and config are automatically injected by Terraform and GCP.

---

## 📚 API Documentation

- **Main endpoints:**

  - `POST /tasks` – Create a task
  - `GET /tasks` – List tasks
  - `GET /tasks/:id` – Get task details
  - `PUT /tasks/:id` – Update a task
  - `DELETE /tasks/:id` – Delete a task
  - `GET /healthz` – Healthcheck
  - `GET /readyz` – Readiness

- **Authentication:** JWT (header `Authorization: Bearer <token>`)

- **Task model:**
  ```json
  {
    "id": "uuid",
    "title": "string",
    "content": "string",
    "due_date": "YYYY-MM-DD",
    "done": false,
    "last_request_timestamp": "RFC3339",
    "created_at": "RFC3339",
    "updated_at": "RFC3339"
  }
  ```

---

## 🧪 Testing

- Go unit tests:
  ```bash
  go test ./app/...
  ```
- To test the API: use Postman, curl, or any HTTP client.

---

## 🔒 Security

- Secrets are never hardcoded: everything goes through Secret Manager and Workload Identity
- DB access is private IP only
- Restrictive firewall rules on GCP
- JWT authentication required on all API routes (except healthz/readyz)
- CI/CD secured via IAM and Artifact Registry

---

For more infrastructure details, see `terraform/docs/README.md` and other files in the `terraform/docs/` folder.
