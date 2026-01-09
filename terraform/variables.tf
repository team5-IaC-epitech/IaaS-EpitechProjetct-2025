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
  default     = "team5-vpc-dev"
}

variable "nat_subnet_name" {
  type        = string
  description = "Name of the subnet for NAT"
  default     = "team5-nat-subnet-dev"
}

variable "gke_subnet_name" {
  type        = string
  description = "Name of the subnet for GKE"
  default     = "team5-gke-subnet-dev"
}

variable "router_name" {
  type        = string
  description = "Name of the router"
  default     = "team5-router-dev"
}

variable "nat_name" {
  type        = string
  description = "Name of the NAT"
  default     = "team5-nat-dev"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/20"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "team5-gke-cluster-dev"
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
  default     = "pods-range"
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
  default     = "services-range"
}

variable "app_pool_machine_type" {
  description = "Machine type for application pool nodes"
  type        = string
  default     = "e2-medium"
}

variable "create_system_node_pool" {
  description = "Boolean to create a system node pool"
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Minimum number of nodes in the Node Pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the Node Pool"
  type        = number
  default     = 5
}

variable "node_count" {
  description = "Number of nodes in the Node Pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB for GKE nodes"
  type        = number
  default     = 10
}

variable "preemptible" {
  description = "Boolean to use preemptible VMs for GKE nodes"
  type        = bool
  default     = false
}

# Cloud SQL variables
variable "cloudsql_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "cloudsql_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 10
}

variable "cloudsql_database_name" {
  description = "Cloud SQL database name"
  type        = string
  default     = "taskmanager"
}

variable "cloudsql_user_name" {
  description = "Cloud SQL user name"
  type        = string
  default     = "taskmanager"
}

# Application variables
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "task-manager"
}
