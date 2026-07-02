# Cost Estimate

This document gives a rough planning estimate for the MVP. Actual AWS costs depend on region, usage, instance sizes, storage, traffic, backups, and free tier eligibility.

## MVP Resources

| Resource | Example Choice | Cost Notes |
| --- | --- | --- |
| EC2 | Small burstable instance | Charged per running hour and storage used |
| EBS | Root volume for WordPress | Charged by provisioned GB |
| RDS MySQL | Small single-AZ instance | Charged per running hour, storage, and backups |
| VPC | Custom VPC, route tables, security groups | Usually no direct charge for basic VPC components |
| S3 | Future backups or media storage | Charged by storage, requests, and transfer |
| Data Transfer | Public web traffic | Charged based on outbound transfer |

## Cost Control Tips

- Use the dev environment only when actively testing.
- Destroy dev resources when finished.
- Start with small instance sizes.
- Avoid NAT gateways in early dev unless they are required.
- Monitor RDS backup retention and snapshot storage.
- Set AWS Budgets alerts before deployment.

## Production Cost Considerations

Production hardening may add:

- Application Load Balancer.
- NAT gateway.
- Multiple EC2 instances.
- Multi-AZ RDS.
- CloudFront.
- WAF.
- CloudWatch logs and metrics.
- Automated backup storage.

These services improve reliability and security, but they also increase monthly cost.

