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
  architecture    = "wp-rds"
  deployment_name = var.deployment_name != "" ? var.deployment_name : var.project_name

  common_tags = {
    Project      = "wordpress-flagship"
    Architecture = local.architecture
    Deployment   = local.deployment_name
    ManagedBy    = "terraform"
    Purpose      = "wordpress-demo"
  }
}

# wp-rds is the more realistic development environment.
# It keeps WordPress on EC2 and moves MySQL into RDS private subnets.
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

module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  private_subnet_ids  = module.vpc.private_subnet_ids
  database_sg_id      = module.security.database_sg_id
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  skip_final_snapshot = true
  common_tags         = local.common_tags
}

module "backup_bucket" {
  source = "../../modules/s3"

  project_name = var.project_name
  bucket_name  = var.backup_bucket_name
  common_tags  = local.common_tags
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
  install_mode     = "rds"
  site_title       = var.site_title
  # wp-rds keeps EC2 user data small so Terraform destroy is not blocked by
  # AWS's 16 KB user_data limit. The RDS + S3 lab is generated during bootstrap.
  site_archive_base64 = ""
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  db_host             = module.rds.db_endpoint

  wp_admin_user     = var.wp_admin_user
  wp_admin_password = var.wp_admin_password
  wp_admin_email    = var.wp_admin_email

  enable_s3_access      = true
  s3_backup_bucket_name = module.backup_bucket.bucket_name
  s3_backup_bucket_arn  = module.backup_bucket.bucket_arn
}
