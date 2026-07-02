variable "aws_region" {
  description = "AWS region where dev resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to tag and name AWS resources."
  type        = string
  default     = "wordpress-flagship-dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the WordPress instance. Replace with your own IP range."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance size for the WordPress server."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
  default     = "replace-with-your-key-pair"
}

variable "db_name" {
  description = "Initial MySQL database name for WordPress."
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Initial MySQL username for WordPress."
  type        = string
  default     = "wordpress_user"
}

variable "db_password" {
  description = "Initial MySQL password. Provide a real value outside Git."
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_DO_NOT_USE_IN_PRODUCTION"
}

