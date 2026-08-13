locals {
  module_tags = length(var.common_tags) > 0 ? var.common_tags : {
    Project = var.project_name
  }
}

resource "aws_security_group" "wordpress" {
  name        = "${var.project_name}-wordpress-sg"
  description = "Allow web and optional SSH access to the WordPress EC2 instance."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet for the MVP."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from a trusted IP range. Restrict this before real use."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow outbound internet access for package installation."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, {
    Name      = "${var.project_name}-wordpress-sg"
    Component = "security"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Allow MySQL access only from the WordPress EC2 security group."
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from WordPress EC2."
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress.id]
  }

  egress {
    description = "Allow outbound responses."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, {
    Name      = "${var.project_name}-database-sg"
    Component = "security"
  })
}
