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
  default     = "10.0.0.0/20"
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

variable "disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-balanced"
}

variable "runners_pool_machine_type" {
  description = "Machine type for runners pool nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "runners_pool_min_nodes" {
  description = "Minimum number of nodes in runners pool"
  type        = number
  default     = 1
}

variable "runners_pool_max_nodes" {
  description = "Maximum number of nodes in runners pool"
  type        = number
  default     = 5
}

variable "app_pool_min_nodes" {
  description = "Minimum number of nodes in application pool"
  type        = number
  default     = 2
}

variable "app_pool_max_nodes" {
  description = "Maximum number of nodes in application pool"
  type        = number
  default     = 10
}

variable "pods_range_name" {
  description = "Name of the secondary IP range"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
}

variable "app_pool_machine_type" {
  description = "Machine type for application pool nodes"
  type        = string
  default     = "e2-medium"
}

