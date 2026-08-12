# wp-rds Guide

`wp-rds` is the more realistic development environment.

It creates one EC2 instance for WordPress, one RDS MySQL database in private subnets, and one S3 bucket reserved for backups. It does not include NAT Gateway, Load Balancer, or CloudFront yet.

## Best Use Cases

- Demonstrating separation between application and database tiers.
- Practicing private RDS networking.
- Testing backup workflows with S3.
- Preparing for later production hardening.

## Deploy

Guided deployment:

```bash
./scripts/start-demo.sh
```

Choose `wp-rds` when the launcher asks for the environment.

The database password is the hidden RDS MySQL login WordPress uses internally. The WordPress admin password should remain a separate password for the `/wp-admin/` browser login.

The launcher also asks for a globally unique S3 backup bucket name. The default includes your project name, AWS region, and AWS account ID to reduce naming conflicts.

After the instance finishes bootstrapping:

- Visit `/` for the WordPress site.
- Visit `/wp-admin/` for WordPress admin.
- Visit `/demo/` for the static Terraform/AWS demo pages.
- Visit `/demo/rds-lab.php` for the admin-only RDS + S3 lab.

## RDS + S3 Lab

The `wp-rds` bootstrap creates an admin-only demo page at `/demo/rds-lab.php`.

This page lets a WordPress administrator:

- Add simple demo rows to the RDS-backed WordPress database.
- Edit row text and status values.
- Upload a file to the S3 backup bucket and link the S3 URI to a database row.

This is meant to make the RDS and S3 backend visible during portfolio demos. It is not a production file manager.

Manual deployment:

```bash
cd terraform/environments/wp-rds
terraform init
terraform plan
terraform apply
```

The `backup_bucket_name` value must be globally unique. Keep real database and WordPress admin passwords out of Git.

## Seed Demo Content

After WordPress is installed, copy the seed script to the EC2 instance and run it:

```bash
scp scripts/seed-wordpress.sh ubuntu@your-instance-public-dns:/tmp/seed-wordpress.sh
ssh ubuntu@your-instance-public-dns "chmod +x /tmp/seed-wordpress.sh && sudo SITE_URL='http://your-instance-public-dns' /tmp/seed-wordpress.sh"
```

## Destroy

```bash
./scripts/destroy-stack.sh --env wp-rds --profile your-profile-name
```

The `wp-rds` environment costs more than `wp-lite` because RDS runs as a separate managed database. The destroy helper removes the Terraform-managed EC2 instance, RDS database, S3 backup bucket, IAM role/profile, VPC resources, and security groups.

The S3 bucket is configured for demo cleanup with `force_destroy`, which allows Terraform to delete uploaded lab files during `terraform destroy`. Do not use this setting for production buckets that must preserve client backups.

To inspect possible project resources without deleting anything:

```bash
./scripts/destroy-stack.sh --env wp-rds --scan-only --profile your-profile-name
```

## Diagnose

For a safe read-only check of the EC2 instance, RDS database, S3 bucket, and HTTP endpoint:

```bash
AWS_PROFILE=your-profile-name ./scripts/diagnose-wp-rds.sh
```
