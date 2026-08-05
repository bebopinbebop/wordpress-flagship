# dev-lite Guide

`dev-lite` is the low-cost demo environment.

It creates one EC2 instance and installs both WordPress and MariaDB on that same instance. It does not create RDS, NAT Gateway, Load Balancer, or CloudFront.

## Best Use Cases

- Portfolio demos.
- Short-lived screenshots.
- Practicing Terraform workflows.
- Testing WordPress bootstrap scripts.

## Deploy

Guided deployment:

```bash
./scripts/start-demo.sh
```

When prompted for `Static website folder path`, press Enter to use `website/default-site`, or enter another folder that contains `index.html`.

After the instance finishes bootstrapping:

- Visit `/` for the WordPress site.
- Visit `/wp-admin/` for WordPress admin.
- Visit `/demo/` for the static Terraform/AWS demo pages.

Manual deployment:

```bash
cd terraform/environments/dev-lite
terraform init
terraform plan
terraform apply
```

Use placeholder values in committed files. Provide real passwords only through local variables, environment variables, or an ignored `.tfvars` file.

## Seed Demo Content

After WordPress is installed, copy the seed script to the instance and run it:

```bash
scp scripts/seed-wordpress.sh ubuntu@your-instance-public-dns:/tmp/seed-wordpress.sh
ssh ubuntu@your-instance-public-dns "chmod +x /tmp/seed-wordpress.sh && sudo SITE_URL='http://your-instance-public-dns' /tmp/seed-wordpress.sh"
```

## Destroy

Destroy this environment when the demo is finished.

```bash
terraform destroy
```
