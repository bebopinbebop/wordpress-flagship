output "instance_id" {
  description = "ID of the WordPress EC2 instance."
  value       = aws_instance.wordpress.id
}

output "public_ip" {
  description = "Public IP address of the WordPress EC2 instance."
  value       = aws_instance.wordpress.public_ip
}

output "public_dns" {
  description = "Public DNS name of the WordPress EC2 instance."
  value       = aws_instance.wordpress.public_dns
}

