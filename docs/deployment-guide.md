# Deployment Guide

This guide explains the intended deployment flow for the MVP AWS WordPress platform.

## Prerequisites

- AWS account.
- AWS CLI configured with a named profile.
- Terraform installed locally.
- An EC2 key pair created in the target AWS region.
- A safe way to provide database credentials, such as local environment variables or a secrets manager.

## Important Secret Reminder

Never commit real secrets to Git.

Do not commit:

- AWS access keys.
- Database passwords.
- Private SSH keys.
- Terraform state files.
- `.tfvars` files containing sensitive values.

## Environment Layout

- `terraform/environments/dev-lite` is for the lowest-cost demos with WordPress and MariaDB on one EC2 instance.
- `terraform/environments/dev-rds` is for testing WordPress on EC2 with RDS MySQL in private subnets.
- `terraform/environments/prod` is for production-like configuration.
- Shared infrastructure logic lives in `terraform/modules`.

## MVP Deployment Flow

1. Review the variables in the selected environment.
2. Replace placeholder values locally using environment variables, CLI variables, or an uncommitted `.tfvars` file.
3. Initialize Terraform.

```bash
cd terraform/environments/dev-lite
terraform init
```

4. Preview the infrastructure changes.

```bash
terraform plan
```

5. Apply the changes only after reviewing the plan.

```bash
terraform apply
```

6. SSH into the EC2 instance if needed and review the WordPress installation logs.
7. Open the EC2 public DNS name or load balancer URL in a browser.
8. Complete the WordPress setup wizard.

## Suggested MVP Inputs

Use placeholder values in committed files and provide real values only at deployment time.

```bash
terraform apply \
  -var="aws_region=us-east-1" \
  -var="project_name=aws-wordpress-terraform-platform" \
  -var="db_name=wordpress" \
  -var="db_username=wordpress_user" \
  -var="db_password=replace-with-a-secure-value"
```

## Destroying Dev Infrastructure

For dev environments, destroy resources when they are no longer needed.

```bash
terraform destroy
```

Be careful with production resources because destroying infrastructure can remove databases, storage, and running servers.
