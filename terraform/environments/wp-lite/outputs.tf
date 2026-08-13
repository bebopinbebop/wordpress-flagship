output "instance_id" {
  description = "EC2 instance ID for the wp-lite WordPress server."
  value       = module.ec2.instance_id
}

output "wordpress_public_ip" {
  description = "Public IP address for the wp-lite WordPress EC2 instance."
  value       = module.ec2.public_ip
}

output "wordpress_url" {
  description = "HTTP URL for the wp-lite WordPress site."
  value       = "http://${module.ec2.public_dns}"
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
