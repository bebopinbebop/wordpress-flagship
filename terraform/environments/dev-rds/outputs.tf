output "wordpress_public_ip" {
  description = "Public IP address for the dev-rds WordPress EC2 instance."
  value       = module.ec2.public_ip
}

output "wordpress_url" {
  description = "HTTP URL for the dev-rds WordPress site."
  value       = "http://${module.ec2.public_dns}"
}

output "database_endpoint" {
  description = "RDS endpoint used by WordPress."
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "backup_bucket_name" {
  description = "S3 bucket reserved for backups."
  value       = module.backup_bucket.bucket_name
}

