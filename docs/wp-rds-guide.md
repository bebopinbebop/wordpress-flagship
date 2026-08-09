# wp-rds Guide

`wp-rds` is the more realistic development environment.

It creates one EC2 instance for WordPress, one RDS MySQL database in private subnets, and one S3 bucket reserved for backups. It does not include NAT Gateway, Load Balancer, or CloudFront yet.

## Best Use Cases

- Demonstrating separation between application and database tiers.
- Practicing private RDS networking.
- Testing backup workflows with S3.
- Preparing for later production hardening.

## Deploy

Guided deployment is not active yet. The main startup script recognizes `wp-rds` as a future branch and exits before running Terraform.

```bash
./scripts/start-demo.sh
```

When this branch is finalized, the database password will be the hidden RDS login WordPress uses internally. The WordPress admin password should remain a separate password for the `/wp-admin/` browser login.

After the instance finishes bootstrapping:

- Visit `/` for the WordPress site.
- Visit `/wp-admin/` for WordPress admin.
- Visit `/demo/` for the static Terraform/AWS demo pages.

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
terraform destroy
```

The wp-rds environment costs more than wp-lite because RDS runs as a separate managed database.
