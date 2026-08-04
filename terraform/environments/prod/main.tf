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

# Production starts with the same MVP modules as dev.
# Harden this environment before hosting real traffic.
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "security" {
  source = "../../modules/security"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  private_subnet_ids  = module.vpc.private_subnet_ids
  database_sg_id      = module.security.database_sg_id
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  skip_final_snapshot = false
}

module "ec2" {
  source = "../../modules/ec2"

  project_name     = var.project_name
  public_subnet_id = module.vpc.public_subnet_ids[0]
  wordpress_sg_id  = module.security.wordpress_sg_id
  instance_type    = var.instance_type
  key_name         = var.key_name
  install_mode     = "rds"
  site_title       = var.site_title
  db_name          = var.db_name
  db_username      = var.db_username
  db_password      = var.db_password
  db_host          = module.rds.db_endpoint
}
