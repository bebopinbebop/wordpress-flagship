output "instance_id" {
  description = "EC2 instance ID for the dev-lite WordPress server."
  value       = module.ec2.instance_id
}

output "wordpress_public_ip" {
  description = "Public IP address for the dev-lite WordPress EC2 instance."
  value       = module.ec2.public_ip
}

output "wordpress_url" {
  description = "HTTP URL for the dev-lite WordPress site."
  value       = "http://${module.ec2.public_dns}"
}
