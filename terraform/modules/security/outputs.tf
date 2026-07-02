output "wordpress_sg_id" {
  description = "Security group ID for the WordPress EC2 instance."
  value       = aws_security_group.wordpress.id
}

output "database_sg_id" {
  description = "Security group ID for the RDS database."
  value       = aws_security_group.database.id
}

