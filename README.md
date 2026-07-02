# WordPress-Flagship

![Project Logo](images/aws_terra_wp.png)

A project for deploying a WordPress hosting platform on AWS with Terraform.

The project supports two beginner-friendly development environments:

- `dev-lite`: one EC2 instance with WordPress and MariaDB installed locally. This is the cheapest demo path and is intended to be destroyed after use.
- `dev-rds`: one EC2 instance running WordPress, with RDS MySQL in private subnets and an S3 bucket reserved for backups.

Both development environments intentionally avoid NAT Gateway, Load Balancer, and CloudFront in the first MVP to keep costs and complexity low.

## Architecture Goals

- Build a repeatable WordPress infrastructure using Terraform.
- Keep networking, security, compute, database, and storage concerns separated into modules.
- Support separate `dev-lite`, `dev-rds`, and `prod` environments.
- Use placeholder variables for sensitive values and never commit real secrets.
- Start with a simple EC2 + RDS MVP, then evolve toward high availability, backups, monitoring, and automation.

## MVP Architecture Options

### dev-lite

- Custom VPC with public and private subnets.
- One EC2 instance in a public subnet.
- WordPress and MariaDB installed on the same instance.
- No RDS, NAT Gateway, Load Balancer, or CloudFront.
- Best for low-cost demos and portfolio screenshots.

### dev-rds

- Custom VPC with public and private subnets.
- One EC2 instance in a public subnet.
- RDS MySQL database in private subnets.
- S3 bucket for future backups.
- No NAT Gateway, Load Balancer, or CloudFront yet.

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
│   ├── cost-control.md
│   ├── cost-estimate.md
│   ├── dev-lite-guide.md
│   ├── dev-rds-guide.md
│   ├── deployment-guide.md
│   └── security.md
├── scripts/
│   └── install-terraform.sh
│   ├── install-wordpress-local-db.sh
│   ├── install-wordpress-rds.sh
│   ├── install-wordpress.sh
│   └── seed-wordpress.sh
└── terraform/
    ├── environments/
    │   ├── dev-lite/
    │   ├── dev-rds/
    │   └── prod/
    └── modules/
        ├── ec2/
        ├── rds/
        ├── s3/
        ├── security/
        └── vpc/
```

## Phases

### Phase 1: Development MVPs

- Deploy `dev-lite` for low-cost single-instance demos.
- Deploy `dev-rds` for a more realistic EC2 + RDS architecture.
- Seed demo WordPress content with WP-CLI.
- Document deployment, security, and cost controls.

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

Secrets are saved as either env variables or in AWS Secret Manager
