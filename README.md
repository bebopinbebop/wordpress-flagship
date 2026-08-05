# WordPress-Flagship

![Project Logo](images/aws_terra_wp.png)

A Terraform-based AWS WordPress hosting platform built as a professional portfolio project.

This project demonstrates how to launch a live WordPress demo site on AWS with reusable Terraform modules, clear documentation, cost-conscious environment choices, and beginner-friendly automation.

It has two practical goals:

- Build a new WordPress site on AWS with Terraform-managed hosting.
- Provide a repeatable target platform for migrating/rehosting existing WordPress client sites.

## What This Demonstrates

- Terraform module design for AWS infrastructure.
- VPC networking with public and private subnets.
- EC2 bootstrap automation with user data.
- WordPress installation on AWS.
- WordPress admin editing from `/wp-admin/`.
- Local MariaDB for low-cost demos.
- RDS MySQL for a more realistic database tier.
- S3 backup bucket planning.
- Safe handling of local variables and secrets.
- GitHub Actions checks for Terraform and Bash scripts.

## Demo Environments

### dev-lite

`dev-lite` is the lowest-cost demo path.

- One EC2 instance in a public subnet.
- WordPress and MariaDB installed locally on the instance.
- No RDS, NAT Gateway, Load Balancer, or CloudFront.
- Best for quick portfolio demos that can be destroyed after use.

### dev-rds

`dev-rds` is the more realistic development architecture.

- One EC2 instance running WordPress.
- RDS MySQL database in private subnets.
- S3 bucket reserved for backups.
- No NAT Gateway, Load Balancer, or CloudFront yet.
- Best for showing database separation and AWS networking skills.

## Guided Quickstart

Use the guided launcher from WSL or another Bash shell:

```bash
./scripts/start-demo.sh
```

The script asks for:

- Environment: `dev-lite` or `dev-rds`
- Website display name
- Static website folder path
- AWS CLI profile
- AWS region
- EC2 key pair name
- SSH allowed CIDR
- EC2 instance type
- WordPress database settings

It writes an ignored local `terraform.tfvars`, runs Terraform, and prints the final WordPress URL output.

By default, the launcher packages [website/default-site](website/default-site) and deploys it as the static infrastructure demo under `/demo/`. You can point the prompt at another folder if you want to deploy your own static HTML/CSS/JS project. The folder must contain an `index.html` file.

WordPress owns the homepage at `/`, and the admin dashboard is available at `/wp-admin/`.

The script does not ask for AWS access keys. Use an AWS CLI profile or AWS SSO:

```bash
aws configure sso
aws sso login --profile your-profile-name
```

## Cleanup

AWS resources can cost money while they are running. Destroy demo environments when you are finished:

```bash
./scripts/destroy-stack.sh --env dev-lite --profile your-profile-name
```

Scan without deleting anything:

```bash
./scripts/destroy-stack.sh --scan-only --profile your-profile-name
```

Destroy both development environments:

```bash
./scripts/destroy-stack.sh --env all --profile your-profile-name
```

Production cleanup is blocked unless you explicitly add `--include-prod`.

## Manual Deployment

```bash
cd terraform/environments/dev-lite
terraform init
terraform plan
terraform apply
terraform output wordpress_url
```

For the RDS-backed demo:

```bash
cd terraform/environments/dev-rds
terraform init
terraform plan
terraform apply
terraform output wordpress_url
```

## Project Structure

```text
.
|-- .github/
|   `-- workflows/
|       `-- terraform-checks.yml
|-- docs/
|   |-- cost-control.md
|   |-- cost-estimate.md
|   |-- deployment-guide.md
|   |-- dev-lite-guide.md
|   |-- dev-rds-guide.md
|   |-- migration-guide.md
|   |-- portfolio-case-study.md
|   `-- security.md
|-- images/
|   `-- aws_terra_wp.png
|-- scripts/
|   |-- diagnose-dev-lite.sh
|   |-- install-terraform.sh
|   |-- install-wordpress-local-db.sh
|   |-- install-wordpress-rds.sh
|   |-- install-wordpress.sh
|   |-- prepare-migration.sh
|   |-- seed-wordpress.sh
|   |-- start-demo.sh
|   `-- wait-for-site.sh
|-- website/
|   `-- default-site/
|       |-- about.html
|       |-- index.html
|       |-- services.html
|       `-- assets/
`-- terraform/
    |-- environments/
    |   |-- dev-lite/
    |   |-- dev-rds/
    |   `-- prod/
    `-- modules/
        |-- ec2/
        |-- rds/
        |-- s3/
        |-- security/
        `-- vpc/
```

## Tech Stack

- Terraform
- AWS VPC
- AWS EC2
- AWS RDS MySQL
- AWS S3
- Bash
- WordPress
- Apache
- PHP
- MariaDB

## Roadmap

### Phase 1: Demo Reliability

- Make `dev-lite` deploy cleanly from the guided launcher.
- Print the live website URL at the end of deployment.
- Keep local state and secrets out of Git.
- Add screenshots of the deployed demo.

### Phase 2: RDS Architecture

- Validate `dev-rds` end to end.
- Document private RDS networking.
- Add backup and restore examples.
- Add a specific `dev-rds` architecture diagram.

### Phase 3: Production Hardening

- Add HTTPS with an Application Load Balancer and ACM certificate.
- Move EC2 instances into private subnets.
- Use SSM Session Manager instead of public SSH.
- Add CloudWatch logs, alarms, and dashboards.

### Phase 4: Scalability

- Store WordPress uploads in S3.
- Add CloudFront CDN.
- Add Auto Scaling Group support.
- Add ElastiCache for object or page caching.

## Secret Handling

Do not commit real AWS credentials, database passwords, private keys, `.tfvars` files, or Terraform state files.

Use AWS CLI profiles, AWS SSO, local ignored `terraform.tfvars` files, environment variables, AWS Secrets Manager, or AWS Systems Manager Parameter Store.
