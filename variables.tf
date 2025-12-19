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
  type = string
  description = "GKE Autopilot cluster name"
}