# Security Notes

This project starts with a simple MVP and should be hardened before production use.

## Current MVP Security Goals

- Place the database in private subnets.
- Allow MySQL traffic only from the WordPress EC2 security group.
- Allow HTTP access to the WordPress instance for initial testing.
- Keep all real secrets outside the repository.
- Use least-privilege IAM policies as the project grows.

## Secrets

Do not store real secrets in Terraform files, scripts, Git history, or README examples.

Use one of these safer options:

- AWS Secrets Manager.
- AWS Systems Manager Parameter Store.
- Environment variables in a secure CI/CD system.
- Local `.tfvars` files that are ignored by Git.

## Network Security

The MVP allows a public EC2 instance so the first version is easier to test.

Future production improvements should include:

- Application Load Balancer in public subnets.
- EC2 instances in private subnets.
- HTTPS with AWS Certificate Manager.
- Restricted SSH access by IP address or Session Manager instead of open SSH.
- VPC endpoints where appropriate.

## Database Security

- Disable public access for RDS.
- Use private database subnets.
- Enable encryption at rest.
- Enable automated backups.
- Rotate database credentials.
- Avoid using the database master user in application code when possible.

## WordPress Security

- Keep WordPress core, themes, and plugins updated.
- Use strong admin passwords and multi-factor authentication where available.
- Install only trusted plugins.
- Limit file write access where possible.
- Add web application firewall protection before production.

