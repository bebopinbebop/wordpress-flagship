output "instance_id" {
  description = "EC2 instance ID for the wp-rds WordPress server."
  value       = module.ec2.instance_id
}

output "wordpress_public_ip" {
  description = "Public IP address for the wp-rds WordPress EC2 instance."
  value       = module.ec2.public_ip
}

output "wordpress_url" {
  description = "HTTP URL for the wp-rds WordPress site."
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

output "rds_s3_lab_url" {
  description = "Admin-only demo page that writes rows to RDS and uploads files to S3."
  value       = "http://${module.ec2.public_dns}/demo/rds-lab.php"
}

output "architecture" {
  description = "WordPress Flagship architecture identifier."
  value       = local.architecture
}

output "deployment_name" {
  description = "Unique deployment identifier used by the standard tagging model."
  value       = local.deployment_name
}

output "common_tags" {
  description = "Standard non-sensitive tags planned for WordPress Flagship AWS resources."
  value       = local.common_tags
}
