variable "project_id" {
  type        = string
  description = "Cloud project ID"
  default     = "iaasepitech"
}

variable "region" {
  type        = string
  description = "Region for resources"
  default     = "europe-west9"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
  default     = "vpc-iaas"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.1.0/24"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "team5-gke-cluster"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "node_count" {
  description = "Number of nodes in the GKE cluster"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes in the GKE cluster"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the GKE cluster"
  type        = number
  default     = 5
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 1
}

variable "disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-balanced"
}

variable "preemptible" {
  description = "Whether to use preemptible VMs for GKE nodes"
  type        = bool
  default     = false
}

variable "create_system_node_pool" {
  description = "Whether to create a system node pool"
  type        = bool
  default     = false
}