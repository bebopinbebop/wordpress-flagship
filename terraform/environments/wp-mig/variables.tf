variable "aws_region" {
  description = "AWS region where wp-mig resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to tag and name migration resources."
  type        = string
  default     = "wordpress-wp-mig"
}

variable "deployment_name" {
  description = "Unique deployment identifier used by the standard tagging model. Defaults to project_name when left blank."
  type        = string
  default     = ""

  validation {
    condition     = var.deployment_name == "" || can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", var.deployment_name))
    error_message = "deployment_name must be blank or a lowercase kebab-case value between 3 and 64 characters."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the custom migration VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the migration EC2 instance."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance size for the migration target WordPress server."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
  default     = "replace-with-your-key-pair"
}

variable "site_title" {
  description = "Friendly website name shown on the migrated WordPress target."
  type        = string
  default     = "Migrated WordPress Demo"
}

variable "site_archive_path" {
  description = "Reserved for compatibility with the launcher. Migration content is moved by scripts, not user_data."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Initial RDS MySQL database name for the migration target."
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Initial RDS MySQL username for WordPress."
  type        = string
  default     = "wpmigadmin"
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
  description = "Globally unique S3 bucket name for migration artifacts and backups."
  type        = string
  default     = "replace-with-globally-unique-wp-mig-artifact-bucket"
}

variable "source_wordpress_url" {
  description = "Planning value for the source WordPress URL. Used by docs/scripts, not infrastructure."
  type        = string
  default     = "https://source.example.com"
}

variable "target_wordpress_url" {
  description = "Planning value for the final target WordPress URL after migration or DNS cutover."
  type        = string
  default     = "https://target.example.com"
}
