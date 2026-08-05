variable "project_name" {
  description = "Name used to tag and name EC2 resources."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID where the MVP WordPress instance will run."
  type        = string
}

variable "wordpress_sg_id" {
  description = "Security group ID for the WordPress EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name."
  type        = string
}

variable "install_mode" {
  description = "WordPress install mode. Use local-db for dev-lite or rds for dev-rds."
  type        = string
  default     = "rds"

  validation {
    condition     = contains(["local-db", "rds"], var.install_mode)
    error_message = "install_mode must be either local-db or rds."
  }
}

variable "site_title" {
  description = "Friendly website name shown on the demo landing page."
  type        = string
  default     = "Cloud WordPress Demo"
}

variable "site_archive_base64" {
  description = "Base64-encoded zip archive for the static website placed in /var/www/html."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "WordPress database name."
  type        = string
}

variable "db_username" {
  description = "WordPress database username."
  type        = string
}

variable "db_password" {
  description = "WordPress database password. Provide securely outside Git."
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "RDS database endpoint."
  type        = string
}
