# IaaS-EpitechProjetct-2025

## Prerequisites

Ensure the following tools are installed on your system:

- **Terraform CLI**: For managing infrastructure as code.
- **Git CLI**: For version control.
- **Cloud Provider CLI**: For interacting with your cloud provider GDP

## Setup Instructions

1. Authenticate with Google Cloud:

   ```bash
   gcloud auth login && gcloud auth application-default login
   ```

## Creating a Google Cloud Storage Bucket

To create a Google Cloud Storage bucket via the web console, follow these steps:

1. Navigate to **Cloud Storage → Buckets** in the Google Cloud Console.
2. Click on **Create**.
3. Fill in the required parameters:
   - **Name**: Provide a globally unique name (e.g., `my-unique-bucket-name`).
   - **Location**:
     - Choose a **Region** (e.g., `europe-west9` for Paris).
     - Or select **Multi-region** if needed.
   - **Storage class**:
     - Use **Standard** for frequent access.
     - Use **Nearline**, **Coldline**, or **Archive** for archival purposes.
   - **Access control**: Select **Uniform** (recommended).
   - **Protection**: Enable **Object Versioning** if necessary.
4. Click **Create** to finalize the bucket setup.

## Terraform Commands

- **Plan**: Preview the changes Terraform will make to your infrastructure.

  ```bash
  terraform plan -var-file=dev.tfvars # For development
  terraform plan -var-file=prod.tfvars # For production
  ```

- **Apply**: Apply the changes to your infrastructure.

  ```bash
  terraform apply -var-file=dev.tfvars # For development
  terraform apply -var-file=prod.tfvars # For production
  ```

- **Destroy**: Tear down the infrastructure managed by Terraform.

  ```bash
  terraform destroy -var-file=dev.tfvars # For development
  terraform destroy -var-file=prod.tfvars # For production
  ```
