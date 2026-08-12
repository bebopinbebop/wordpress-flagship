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
    site_archive = var.site_archive_base64
    db_name      = var.db_name
    db_username  = var.db_username
    db_password  = var.db_password
    db_host      = var.db_host

    wp_admin_user     = var.wp_admin_user
    wp_admin_password = var.wp_admin_password
    wp_admin_email    = var.wp_admin_email

    s3_backup_bucket_name = var.s3_backup_bucket_name
  })
}

data "aws_iam_policy_document" "ec2_assume_role" {
  count = var.s3_backup_bucket_arn != "" ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_demo_access" {
  count = var.s3_backup_bucket_arn != "" ? 1 : 0

  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.s3_backup_bucket_arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${var.s3_backup_bucket_arn}/*"]
  }
}

resource "aws_iam_role" "wordpress_s3" {
  count = var.s3_backup_bucket_arn != "" ? 1 : 0

  name               = "${var.project_name}-wordpress-s3-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role[0].json

  tags = {
    Name    = "${var.project_name}-wordpress-s3-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "wordpress_s3" {
  count = var.s3_backup_bucket_arn != "" ? 1 : 0

  name   = "${var.project_name}-wordpress-s3-demo-policy"
  role   = aws_iam_role.wordpress_s3[0].id
  policy = data.aws_iam_policy_document.s3_demo_access[0].json
}

resource "aws_iam_instance_profile" "wordpress_s3" {
  count = var.s3_backup_bucket_arn != "" ? 1 : 0

  name = "${var.project_name}-wordpress-s3-profile"
  role = aws_iam_role.wordpress_s3[0].name
}

resource "aws_instance" "wordpress" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.wordpress_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.s3_backup_bucket_arn != "" ? aws_iam_instance_profile.wordpress_s3[0].name : null
  user_data              = local.wordpress_user_data

  tags = {
    Name    = "${var.project_name}-wordpress"
    Project = var.project_name
    Site    = var.site_title
  }
}
