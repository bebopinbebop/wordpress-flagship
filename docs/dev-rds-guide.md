# dev-rds Guide

`dev-rds` is the more realistic development environment.

It creates one EC2 instance for WordPress, one RDS MySQL database in private subnets, and one S3 bucket reserved for backups. It does not include NAT Gateway, Load Balancer, or CloudFront yet.

## Best Use Cases

- Demonstrating separation between application and database tiers.
- Practicing private RDS networking.
- Testing backup workflows with S3.
- Preparing for later production hardening.

## Deploy

```bash
cd terraform/environments/dev-rds
terraform init
terraform plan
terraform apply
```

The `backup_bucket_name` value must be globally unique. Keep real database passwords out of Git.

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

The dev-rds environment costs more than dev-lite because RDS runs as a separate managed database.
