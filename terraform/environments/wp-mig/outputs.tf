output "instance_id" {
  description = "EC2 instance ID for the wp-mig migration target."
  value       = module.ec2.instance_id
}

output "wordpress_public_ip" {
  description = "Public IP address for the wp-mig WordPress target."
  value       = module.ec2.public_ip
}

output "wordpress_url" {
  description = "Temporary HTTP URL for the wp-mig WordPress target."
  value       = "http://${module.ec2.public_dns}"
}

output "wordpress_admin_url" {
  description = "Temporary WordPress admin URL for the migration target."
  value       = "http://${module.ec2.public_dns}/wp-admin/"
}

output "database_endpoint" {
  description = "Private RDS endpoint used by the wp-mig target."
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "migration_bucket_name" {
  description = "S3 bucket used for migration artifacts and rollback backups."
  value       = module.migration_bucket.bucket_name
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
