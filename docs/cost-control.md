# Cost Control

This project intentionally separates low-cost demos from more realistic development.

## dev-lite

`dev-lite` is the cheapest option because it uses one EC2 instance for both WordPress and MariaDB.

Cost controls:

- Use a small instance type such as `t3.micro`.
- Destroy the environment after demos.
- Avoid large EBS volumes.
- Do not add NAT Gateway, Load Balancer, or CloudFront for this mode.

## dev-rds

`dev-rds` costs more because RDS runs separately from EC2.

Cost controls:

- Use a small RDS instance class for development.
- Keep backup retention short in dev.
- Destroy the environment when finished.
- Watch snapshot and S3 storage growth.
- Keep NAT Gateway, Load Balancer, and CloudFront out until they are needed.

## AWS Budget Suggestions

- Create an AWS Budget for monthly spend.
- Add email alerts at 50%, 80%, and 100% of the budget.
- Tag all resources with the project name.
- Review idle EC2, RDS, EBS, and snapshot resources weekly.

