# aws-wordpress-terraform-platform

A professional portfolio project for deploying a WordPress hosting platform on AWS with Terraform.

The first MVP deploys a single EC2 instance running WordPress, connected to an RDS MySQL database inside a custom VPC. The project is intentionally structured so it can grow into a more production-ready platform over time.

## Architecture Goals

- Build a repeatable WordPress infrastructure using Terraform.
- Keep networking, security, compute, database, and storage concerns separated into modules.
- Support separate `dev` and `prod` environments.
- Use placeholder variables for sensitive values and never commit real secrets.
- Start with a simple EC2 + RDS MVP, then evolve toward high availability, backups, monitoring, and automation.

## MVP Architecture

- Custom VPC with public and private subnets.
- EC2 instance in a public subnet for the WordPress web server.
- RDS MySQL database in private subnets.
- Security groups that allow web traffic to EC2 and database traffic only from the WordPress instance.
- S3 bucket module reserved for future media, backups, or Terraform state patterns.

## Tech Stack

- Terraform
- AWS VPC
- AWS EC2
- AWS RDS MySQL
- AWS S3
- Bash
- WordPress
- Apache or Nginx
- PHP

## Project Structure

```text
.
├── docs/
│   ├── cost-estimate.md
│   ├── deployment-guide.md
│   └── security.md
├── scripts/
│   └── install-wordpress.sh
└── terraform/
    ├── environments/
    │   ├── dev/
    │   └── prod/
    └── modules/
        ├── ec2/
        ├── rds/
        ├── s3/
        ├── security/
        └── vpc/
```

## Phases

### Phase 1: MVP

- Create the Terraform repository structure.
- Deploy a custom VPC.
- Deploy one EC2 instance for WordPress.
- Deploy one RDS MySQL database.
- Install WordPress with a bootstrap script.
- Document deployment, security, and estimated costs.

### Phase 2: Production Hardening

- Add HTTPS with an Application Load Balancer and ACM certificate.
- Move EC2 instances into private subnets.
- Add NAT gateway or private package installation strategy.
- Add automated RDS backups and snapshot policies.
- Add CloudWatch logs, alarms, and dashboards.

### Phase 3: Scalability

- Add Auto Scaling Group support.
- Store WordPress uploads in S3.
- Add CloudFront CDN.
- Add ElastiCache for object/page caching.
- Split reusable modules into versioned releases.

## Deliverables

- Beginner-friendly Terraform module structure.
- Separate development and production environment folders.
- WordPress installation script.
- Deployment guide.
- Security notes.
- Cost estimate notes.
- A clean GitHub-ready project layout.

## Secret Handling

Do not commit real AWS credentials, database passwords, private keys, `.tfvars` files, or Terraform state files.

Use placeholder variables locally, environment variables, AWS profiles, or a secrets manager when deploying for real.

