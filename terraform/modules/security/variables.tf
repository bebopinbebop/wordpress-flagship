variable "project_name" {
  description = "Name used to tag and name security resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to connect with SSH."
  type        = string
}

