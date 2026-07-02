output "db_endpoint" {
  description = "RDS database endpoint."
  value       = aws_db_instance.mysql.address
}

output "db_instance_id" {
  description = "RDS database instance ID."
  value       = aws_db_instance.mysql.id
}

