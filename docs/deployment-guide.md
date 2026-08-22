# Deployment Guide

This guide explains the intended deployment flow for the MVP AWS WordPress platform.

## Prerequisites

- AWS account.
- AWS CLI configured with a named profile.
- Terraform installed locally.
- Bash-compatible shell on Linux or WSL2 Ubuntu.
- `curl`, `ssh`, `zip`, `unzip`, `tar`, `gzip`, `sha256sum`, and `openssl`.
- An EC2 key pair created in the target AWS region.
- A safe way to provide database and WordPress admin credentials, such as local environment variables, ignored `.tfvars` files, or a secrets manager.

Migration testing also uses a MySQL or MariaDB client. Optional development tools include ShellCheck for Bash linting, `jq` for reading generated JSON manifests, `shfmt` for Bash formatting, and `tflint` for deeper Terraform linting.

On a fresh Ubuntu/Debian or WSL machine, install the local command-line tools with:

```bash
./scripts/install-prereqs.sh
```

This installs local tools only. It does not configure AWS credentials, create an EC2 key pair, or deploy AWS resources.

## Important Secret Reminder

Never commit real secrets to Git.

Do not commit:

- AWS access keys.
- Database passwords.
- WordPress admin passwords.
- Private SSH keys.
- Terraform state files.
- `.tfvars` files containing sensitive values.

## Environment Layout

- `terraform/environments/wp-lite` is for the lowest-cost demos with WordPress and MariaDB on one EC2 instance.
- `terraform/environments/wp-rds` is for testing WordPress on EC2 with RDS MySQL in private subnets and an S3 bucket reserved for backups.
- `terraform/environments/wp-mig` is for provisioning a clean AWS migration target based on the `wp-rds` architecture.
- Shared infrastructure logic lives in `terraform/modules`.

## MVP Deployment Flow

The easiest demo path is the guided launcher:

```bash
./scripts/start-demo.sh
```

The launcher asks which environment path to use: `wp-lite`, `wp-rds`, or `wp-mig`. All three paths continue into Terraform deployment. The `wp-mig` path provisions a migration target, then points you toward the migration readiness worker before export/restore work.

For `wp-lite` and `wp-rds`, the launcher asks for the website name, static website folder, AWS profile, region, key pair, SSH CIDR, database settings, and a separate WordPress admin login. It packages the static website folder into `.generated/`, writes a local ignored `terraform.tfvars` file, waits for WordPress, and prints the site URLs plus the WordPress admin username and password after deployment.

For `wp-rds` and `wp-mig`, the launcher also asks for a globally unique S3 backup/artifact bucket name.

The default website source is:

```bash
website/default-site
```

You can replace that folder or point the launcher at another HTML project. The folder must contain `index.html`.

After bootstrap:

- `/` is the WordPress site and can be edited from `/wp-admin/`.
- `/demo/` is the static infrastructure demo packaged from the website folder.

Use AWS CLI profiles or AWS SSO instead of entering AWS access keys into scripts:

```bash
aws configure sso
aws sso login --profile your-profile-name
```

## Manual Deployment Flow

1. Review the variables in the selected environment.
2. Replace placeholder values locally using environment variables, CLI variables, or an uncommitted `.tfvars` file.
3. Initialize Terraform.

```bash
cd terraform/environments/wp-lite
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
  -var="db_password=replace-with-a-secure-db-value" \
  -var="wp_admin_user=demo_admin" \
  -var="wp_admin_email=admin@example.com" \
  -var="wp_admin_password=replace-with-a-separate-wp-admin-value"
```

## Destroying Dev Infrastructure

For dev environments, destroy resources when they are no longer needed.

```bash
./scripts/destroy-stack.sh --env wp-lite --profile your-profile-name
./scripts/destroy-stack.sh --env wp-rds --profile your-profile-name
./scripts/destroy-stack.sh --env wp-mig --profile your-profile-name
```

Use `--env all` to clean up discovered demo deployments from local Terraform state. Be careful with production resources because destroying infrastructure can remove databases, storage, and running servers.

## Demo Safety Notes

- The default SSH CIDR can be left open for quick demos, but real use should restrict SSH to a trusted IP range.
- `wp-rds` and `wp-mig` use disposable-demo cleanup defaults, including skipped final RDS snapshots and force-destroy S3 buckets.
- HTTPS, stronger backup policy, monitoring, private EC2 placement, and production hardening are intentionally future work.
