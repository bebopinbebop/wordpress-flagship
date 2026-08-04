data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  wordpress_user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    install_mode = var.install_mode
    site_title   = var.site_title
    db_name      = var.db_name
    db_username  = var.db_username
    db_password  = var.db_password
    db_host      = var.db_host
  })
}

resource "aws_instance" "wordpress" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.wordpress_sg_id]
  key_name               = var.key_name
  user_data              = local.wordpress_user_data

  tags = {
    Name    = "${var.project_name}-wordpress"
    Project = var.project_name
    Site    = var.site_title
  }
}
