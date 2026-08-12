# Cost Control

This project intentionally separates low-cost demos from more realistic development.

## wp-lite

`wp-lite` is the cheapest option because it uses one EC2 instance for both WordPress and MariaDB.

Cost controls:

- Use a small instance type such as `t3.micro`.
- Destroy the environment after demos.
- Avoid large EBS volumes.
- Do not add NAT Gateway, Load Balancer, or CloudFront for this mode.

## wp-rds

`wp-rds` costs more because RDS runs separately from EC2.

Cost controls:

- Use a small RDS instance class for development.
- Keep backup retention short in dev.
- Destroy the environment when finished.
- Watch snapshot and S3 storage growth.
- Keep NAT Gateway, Load Balancer, and CloudFront out until they are needed.

## wp-mig

`wp-mig` has a similar cost profile to `wp-rds` because it provisions EC2, RDS, and S3 as a migration target.

Cost controls:

- Use it only while practicing or demonstrating migration.
- Destroy it after validation or recording a portfolio demo.
- Keep migration artifacts small and remove unneeded S3 objects.
- Avoid storing client database dumps longer than necessary.

## AWS Budget Suggestions

- Create an AWS Budget for monthly spend.
- Add email alerts at 50%, 80%, and 100% of the budget.
- Tag all resources with the project name.
- Review idle EC2, RDS, EBS, and snapshot resources weekly.

## Cleanup Script

Use the cleanup helper to scan for WordPress Flagship projects and choose one from a numbered list:

```bash
./scripts/destroy-stack.sh --profile your-profile-name
```

The script looks for project names from local Terraform files and AWS resources tagged with `Project`. It can identify `wp-lite`, `wp-rds`, and `wp-mig` deployments that were created by this repository.

You can still destroy a specific environment directly:

```bash
./scripts/destroy-stack.sh --env wp-lite --profile your-profile-name
```

For the RDS-backed environment, use:

```bash
./scripts/destroy-stack.sh --env wp-rds --profile your-profile-name
```

For the migration environment, use:

```bash
./scripts/destroy-stack.sh --env wp-mig --profile your-profile-name
```

This removes the Terraform-managed EC2 instance, RDS database, S3 backup/artifact bucket, IAM role/profile, networking, and security groups. The demo S3 bucket is configured with `force_destroy` so uploaded lab files do not block cleanup.

For `wp-rds` and `wp-mig`, the script also lists matching manual RDS snapshots. Snapshots can keep billing for storage after an RDS database is gone, so the script asks whether to delete matching snapshots after Terraform destroy or when a matching orphaned snapshot is found.

To delete matching snapshots without the extra snapshot prompt:

```bash
./scripts/destroy-stack.sh --env wp-mig --profile your-profile-name --delete-snapshots
```

To always preserve snapshots:

```bash
./scripts/destroy-stack.sh --env wp-mig --profile your-profile-name --keep-snapshots
```

Use scan-only mode before or after cleanup:

```bash
./scripts/destroy-stack.sh --scan-only --profile your-profile-name
```

The script prefers `terraform destroy` because Terraform understands resource dependencies. It also shows tagged AWS resources that may still cost money, such as EC2 instances, EBS volumes, RDS databases, RDS snapshots, NAT gateways, load balancers, IAM roles, instance profiles, and the configured S3 backup bucket.
