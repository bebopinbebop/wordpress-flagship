terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  architecture    = "wp-lite"
  deployment_name = var.deployment_name != "" ? var.deployment_name : var.project_name

  common_tags = {
    Project      = "wordpress-flagship"
    Architecture = local.architecture
    Deployment   = local.deployment_name
    ManagedBy    = "terraform"
    Purpose      = "wordpress-demo"
  }
}

# wp-lite is the lowest-cost demo environment.
# It creates one EC2 instance and installs both WordPress and MariaDB locally.
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  common_tags  = local.common_tags
}

module "security" {
  source = "../../modules/security"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  common_tags      = local.common_tags
}

module "ec2" {
  source = "../../modules/ec2"

  project_name     = var.project_name
  public_subnet_id = module.vpc.public_subnet_ids[0]
  wordpress_sg_id  = module.security.wordpress_sg_id
  instance_type    = var.instance_type
  key_name         = var.key_name
  common_tags      = local.common_tags
  tag_root_volume  = true
  install_mode     = "local-db"
  site_title       = var.site_title
  site_archive_base64 = (
    var.site_archive_path != "" ? filebase64(var.site_archive_path) : ""
  )
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  db_host     = "localhost"

  wp_admin_user     = var.wp_admin_user
  wp_admin_password = var.wp_admin_password
  wp_admin_email    = var.wp_admin_email
}
