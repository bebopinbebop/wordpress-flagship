output "wordpress_public_ip" {
  description = "Public IP address for the WordPress EC2 instance."
  value       = module.ec2.public_ip
}

output "wordpress_url" {
  description = "HTTP URL for the WordPress MVP."
  value       = "http://${module.ec2.public_dns}"
}

output "database_endpoint" {
  description = "RDS endpoint used by WordPress."
  value       = module.rds.db_endpoint
  sensitive   = true
}

