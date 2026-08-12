# wp-mig Environment

`wp-mig` is the migration target environment for the WordPress Flagship project.

It provisions a clean AWS-hosted WordPress target that can receive content from an existing WordPress installation. The first practical demo path is:

```text
source WordPress -> export database and wp-content -> wp-mig target -> restore -> validate
```

## Architecture

- Custom VPC with public and private subnets.
- EC2 WordPress server in a public subnet.
- Private RDS MySQL database for WordPress data.
- S3 bucket for migration artifacts, backups, and rollback material.
- IAM instance profile that allows the EC2 instance to access the migration bucket.

This intentionally reuses the same shared modules as `wp-rds` so the migration path does not duplicate infrastructure logic.

## Migration Rule

Do not blindly copy the old `wp-config.php` into this environment.

Migration scripts should preserve content and database data, but the target must keep the database hostname, username, password, salts, and AWS-specific settings created for this deployment.

## Local Use

Copy `terraform.tfvars.example` to `terraform.tfvars`, replace placeholders locally, then run through `scripts/start-demo.sh` and choose `wp-mig`.

For cleanup:

```bash
./scripts/destroy-stack.sh --env wp-mig --profile your-profile-name
```
