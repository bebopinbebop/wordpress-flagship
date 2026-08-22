# wordpress-flagship

[![Terraform Checks](https://github.com/bebopinbebop/wordpress-flagship/actions/workflows/terraform-checks.yml/badge.svg)](https://github.com/bebopinbebop/wordpress-flagship/actions/workflows/terraform-checks.yml)

<img src = "images/aws_terra_wp.png" width = "500">

## Hosting WordPress on AWS Resources automatically with Terraform as IaC.

This project aims to build a WordPress (WP) project from your terminal onto your AWS account using Terraform-defined resources that coalesce into a functional website.

Terraform was chosen over AWS CloudFormation because Terraform is popular, vendor-neutral, and adaptable to other Cloud Service Providers (CSPs), meaning other companies feel safer having the option to spin up their infrastructure on another platform if their current CSP is lacking.

AWS was chosen due to the huge market share that affords dependability and reliability for projects built on it. The economy-of-scale that AWS provides also functions as a good support network for when things go wrong.

WordPress was chosen due to how it affords companies that may not have a technical background to get a professional image out to their clients, and the huge market share that WordPress has as a Content Management System (CMS).

The project accomplishes WordPress on AWS resources by one of three ways, described below:

1. [wp-lite](#wp-lite-light-version)
2. [wp-rds](#wp-rds-relational-database-services)
3. [wp-mig](#wp-mig-migration)

![Project Breakdown](images/project-breakdown.png)

Each of the aforementioned sections in this project have their own dedicated documentation to act as a guide in how to operate them, with troubleshooting tips and explanations detailing the direction.

In the `Terraform` folder, there are three environments (`wp-lite`, `wp-rds`, `wp-mig`) that each contain their own resource definitions that will be built by `aws`. Some definations are built off from previous ones, such as `wp-rds` being an extended version of `wp-lite`.

In essence, each project section creates an `ec2` instance that is then preloaded with `wordpress`, and then custom Security Groups, IAM permissions and attached resources build the necessary backend to support a fully functional webpage. Each section varies in how much resources are attached to it for a diverse capability set, making each deployment uniquely equipped for a specific mission.

The end goal would be that for an individual to then login to the `\wp-admin` page and edit their WordPress webpage as they prefer.

## wp-lite (Light Version)

**`wp-lite`** is a cost-effective environment that uses Terraform to deploy a complete WordPress stack (Apache, PHP, MariaDB, and WordPress) on a single EC2 instance within a custom AWS VPC. It's intended for portfolio demonstrations, testing, and rapid deployment while keeping AWS costs to a minimum. See further detail [here](docs/wp-lite-guide.md).

- Custom VPC with public and private subnets.
- One EC2 instance in a public subnet that installs WP via its **User Data** that's been altered.
- MariaDB installed on the same instance to support WP functionality like blog postings, plugins, and config files.
- No RDS, NAT Gateway, Load Balancer, or CloudFront.

## wp-rds (Relational Database Services)

**`wp-rds`** is a production-shaped development environment that uses Terraform to deploy a custom AWS VPC, a WordPress EC2 instance, a private Amazon RDS MySQL database, and an S3 bucket for future backup workflows. It costs more than `wp-lite` because RDS runs as a separate managed database.

It separates the web and database tiers while securing the internal networking, managed database provisioning, and infrastructure automation. The environment provides a live WordPress site with data stored in RDS, making it ideal for migration testing, client hosting demonstrations, and preparing for future production enhancements. See further detail [here](docs/wp-rds-guide.md).

- Custom VPC with public and private subnets.
- One EC2 instance in a public subnet.
- RDS MySQL database in private subnets.
- S3 bucket for future backups.
- Admin-only `/demo/rds-lab.php` page that writes demo rows to RDS and uploads files to S3.
- No NAT Gateway, Load Balancer, CloudFront, or HTTPS automation yet.

## wp-mig (Migration)

**`wp-mig`** is a migration-focused environment designed to demonstrate the process of rehosting existing WordPress websites on AWS using Terraform. It provisions a clean AWS migration target based on the `wp-rds` architecture, then uses migration scripts and documentation to guide export, transfer, restore, reconfiguration, validation, rollback, and cleanup. Intended for client migrations, `wp-mig` showcases Infrastructure as Code (IaC), migration automation, and best practices for moving WordPress sites with minimal downtime. See further detail [here](docs/wp-mig-guide.md).

- EC2 web server for the migrated WordPress site
- Amazon RDS MySQL database
- Amazon S3 for backups and migration files
- Custom AWS VPC with public and private subnets
- Secure Security Group configuration
- WP-CLI source preflight
- Initial database export workflow
- Temporary staging/testing URL
- Planned `wp-content` export, S3 transfer, restore, URL replacement, validation, and rollback
- Future DNS cutover planning
- Future HTTPS support (ACM + Load Balancer)
- Future backup, monitoring, and production-readiness validation

## Requirements and Troubleshooting

The primary supported local workflow is Linux/Bash or WSL2 Ubuntu/Bash. PowerShell can be useful for manual troubleshooting, but the project scripts are designed around Bash.

Required local tools:

- `bash`: runs the project scripts.
- `terraform`: plans, validates, creates, and destroys AWS infrastructure.
- `aws`: authenticates with AWS and supports resource discovery.
- `curl`: waits for WordPress and checks HTTP readiness.
- `ssh`: reaches EC2 instances for diagnostics and migration export.
- `zip` and `unzip`: package and unpack the static demo site.
- `tar` and `gzip`: package migration artifacts.
- `sha256sum`: verifies migration artifact checksums.
- `openssl`: generates local demo passwords.

Migration testing also uses:

- `mysql` or `mariadb` client tools.

Optional development/static-analysis tools:

- `shellcheck`: lint Bash scripts locally; CI runs ShellCheck.
- `jq`: useful for inspecting generated migration manifests.
- `shfmt`: useful for formatting Bash, but not required by CI.
- `tflint`: useful for deeper Terraform linting, but not required by CI yet.

On a fresh Ubuntu/Debian or WSL2 machine, install the local command-line tools with:

```bash
./scripts/install-prereqs.sh
```

Then configure AWS with a CLI profile or AWS SSO:

```bash
aws configure sso
aws sso login --profile your-profile-name
```

Do not paste AWS access keys into project scripts.

## Bash Path Portability

The guided scripts are Bash-first and are intended for Linux, WSL2, and Bash-compatible shells. They resolve the project root dynamically from Git when possible, so the project does not depend on a specific checkout folder such as `/mnt/c/Users/<username>/...`.

Generated demo artifacts are written under the ignored `.generated/` folder at the project root. When the launcher writes local `terraform.tfvars`, archive paths are stored relative to the Terraform environment folder instead of using machine-specific absolute paths.

## Deliverables



The deployed site uses WordPress as the main editable website:

```text
/          WordPress site
/wp-admin/ WordPress admin dashboard
/demo/     Static Terraform/AWS infrastructure demo
```

## Architecture Goals

- Build a repeatable WordPress infrastructure using Terraform.
- Keep networking, security, compute, database, and storage concerns separated into modules.
- Support separate `wp-lite`, `wp-rds`, and `wp-mig` environments.
- Use placeholder variables for sensitive values and never commit real secrets.
- Start with simple EC2-based MVPs, then evolve toward HTTPS, domains, backups, monitoring, and production automation.


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

## Continuous Integration

This repository uses GitHub Actions to validate Terraform code on pushes to `main` and on pull requests.

The Terraform Checks workflow runs `terraform fmt -check -recursive`, verifies Bash script syntax recursively under `scripts/`, runs ShellCheck, checks that local Terraform state and `.tfvars` files are not committed, and runs `terraform init -backend=false` plus `terraform validate` for the implemented Terraform environments.

The workflow validates the implemented Terraform environments: `wp-lite`, `wp-rds`, and `wp-mig`.

CI validates infrastructure code only. It does not run `terraform apply` and does not deploy AWS resources.

## Project Structure

```text
.
├── docs/
│   ├── cost-control.md
│   ├── cost-estimate.md
│   ├── wp-mig-guide.md
│   ├── wp-lite-guide.md
│   ├── wp-rds-guide.md
│   ├── deployment-guide.md
│   ├── migration-guide.md
│   ├── portfolio-case-study.md
│   └── security.md
├── scripts/
│   ├── check-migration-readiness.sh
│   ├── destroy-stack.sh
│   ├── diagnose-wp-lite.sh
│   ├── install-terraform.sh
│   ├── install-wordpress-local-db.sh
│   ├── install-wordpress-rds.sh
│   ├── install-wordpress.sh
│   ├── prepare-migration.sh
│   ├── start-demo.sh
│   ├── wait-for-site.sh
│   └── seed-wordpress.sh
├── website/
│   └── default-site/
└── terraform/
    ├── environments/
    │   ├── wp-lite/
    │   ├── wp-mig/
    │   └── wp-rds/
    └── modules/
        ├── ec2/
        ├── rds/
        ├── s3/
        ├── security/
        └── vpc/
```

## Phases

### Phase 1: Development MVPs

- Deploy `wp-lite` for low-cost single-instance demos.
- Reserve `wp-rds` for a more realistic EC2 + RDS architecture.
- Deploy `wp-mig` as a clean AWS target for migration and rehosting workflows.
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
- Guided startup and cleanup scripts.
- WordPress installation and seed scripts.
- Deployment guide.
- Security notes.
- Cost estimate notes.
- Static demo website files under `website/default-site`.
- A clean GitHub-ready project layout.

## Secret Handling

Do not commit real secrets. The guided launcher writes deployment values to an ignored local `terraform.tfvars` file so Terraform can bootstrap the demo without storing credentials in Git.

For the current MVP, keep these values local:

- Database username and password.
- WordPress admin username, email, and password.
- EC2 SSH key material.
- AWS CLI profile configuration.

Future production work should move secrets into AWS Secrets Manager or AWS Systems Manager Parameter Store.

## Resource Identity

AWS resources are being organized around a standard tag identity model:

```text
Project -> Architecture -> Deployment -> Resource
```

Example tags:

```text
Project      = wordpress-flagship
Architecture = wp-rds
Deployment   = demo-001
ManagedBy    = terraform
```

This model is intended to improve resource discovery, cleanup verification, troubleshooting, and future cost reporting. See [docs/tagging-architecture.md](docs/tagging-architecture.md).

Read-only resource discovery is available with:

```bash
./scripts/resources.sh list --architecture wp-lite --deployment wp-lite-test
```

## Demo Security Caveats

This repository is demo-first. It is intentionally easy to create and destroy resources while learning.

- `allowed_ssh_cidr = 0.0.0.0/0` is convenient for demos, but SSH should be restricted to a trusted IP range before real use.
- `skip_final_snapshot = true` is used for disposable RDS demos to avoid leftover snapshot storage costs.
- S3 `force_destroy` is used for disposable demo buckets so uploaded demo files do not block cleanup.
- HTTPS, stronger backup policies, monitoring, private EC2 placement, and production hardening are future work.

## Current Status And TODO

Completed:

- [x] `wp-lite` single-EC2 WordPress demo.
- [x] `wp-rds` EC2 + private RDS MySQL + S3 demo.
- [x] `wp-mig` migration target infrastructure.
- [x] Structured AWS tagging across all three architectures.
- [x] Bash path portability with project-relative generated artifacts.
- [x] Read-only AWS tag discovery.
- [x] `wp-lite` source migration preflight.
- [x] Initial `wp-lite` database export with manifest and checksums.

Next migration work:

- [ ] Export `wp-content` as `wp-content.tar.gz`.
- [ ] Upload migration artifacts to the private `wp-mig` S3 bucket.
- [ ] Add target preflight checks.
- [ ] Back up the target before restore.
- [ ] Restore database and `wp-content` into `wp-mig`.
- [ ] Run WP-CLI search-replace for source and target URLs.
- [ ] Validate migrated WordPress content.
- [ ] Add rollback workflow.
