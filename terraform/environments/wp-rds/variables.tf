variable "aws_region" {
  description = "AWS region where wp-rds resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to tag and name AWS resources."
  type        = string
  default     = "wordpress-wp-rds"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance. Replace with your own IP range."
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

variable "site_title" {
  description = "Friendly website name shown on the demo landing page."
  type        = string
  default     = "Cloud WordPress Demo"
}

variable "site_archive_path" {
  description = "Local path to a zip archive containing the static website files to deploy."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Initial RDS MySQL database name for WordPress."
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Initial RDS MySQL username for WordPress."
  type        = string
  default     = "wordpress_user"
}

variable "db_password" {
  description = "Initial RDS MySQL password. Provide a real value outside Git."
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_DO_NOT_USE_IN_PRODUCTION"
}

variable "wp_admin_user" {
  description = "WordPress administrator username for browser login."
  type        = string
  default     = "demo_admin"
}

variable "wp_admin_password" {
  description = "WordPress administrator password for browser login. Keep this separate from the database password."
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_DO_NOT_USE_IN_PRODUCTION"
}

variable "wp_admin_email" {
  description = "WordPress administrator email address used during first install."
  type        = string
  default     = "admin@example.com"
}

variable "backup_bucket_name" {
  description = "Globally unique S3 bucket name for wp-rds backups."
  type        = string
  default     = "replace-with-globally-unique-wp-rds-backup-bucket"
}
