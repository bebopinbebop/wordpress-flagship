# Portfolio Case Study

## Problem

A small business or freelancer needs a repeatable WordPress hosting setup on AWS. The first version should be affordable enough for demos, but structured well enough to grow into a production architecture.

## Solution

This project provides two Terraform-managed development environments:

- `dev-lite` runs WordPress and MariaDB on one EC2 instance for low-cost demos.
- `dev-rds` runs WordPress on EC2 and MySQL on private RDS subnets for a more realistic client architecture.

Both environments use reusable Terraform modules for VPC, security groups, EC2, RDS, and S3.

The deployed site uses WordPress as the main editable website at `/`, while the static infrastructure demo is served from `/demo/`.

## What This Demonstrates

- Terraform module organization.
- AWS VPC and public subnet networking.
- EC2 bootstrap automation with user data.
- WordPress installation on AWS.
- WordPress admin editing for client-managed content.
- Local MariaDB versus managed RDS tradeoffs.
- S3 backup planning.
- A practical migration workflow for rehosting existing WordPress sites.
- Cost-aware environment design.
- GitHub Actions quality checks.

## Security Choices

- Real secrets are not committed.
- Local `terraform.tfvars` files are ignored by Git.
- RDS is placed in private subnets for `dev-rds`.
- MySQL access is limited to the WordPress EC2 security group.
- SSH access is configurable with `allowed_ssh_cidr`.

## Client Value

This project shows how a WordPress site can be launched in a predictable way, documented clearly, and adapted to different budgets. It is designed for clients who want infrastructure they can understand, reproduce, and improve over time.
