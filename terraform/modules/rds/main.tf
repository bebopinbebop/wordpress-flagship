resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

resource "aws_db_instance" "mysql" {
  identifier               = "${var.project_name}-mysql"
  engine                   = "mysql"
  engine_version           = "8.0"
  instance_class           = var.instance_class
  allocated_storage        = var.allocated_storage
  db_name                  = var.db_name
  username                 = var.db_username
  password                 = var.db_password
  db_subnet_group_name     = aws_db_subnet_group.this.name
  vpc_security_group_ids   = [var.database_sg_id]
  publicly_accessible      = false
  storage_encrypted        = true
  backup_retention_period  = var.backup_retention_period
  delete_automated_backups = var.delete_automated_backups
  skip_final_snapshot      = var.skip_final_snapshot

  tags = {
    Name    = "${var.project_name}-mysql"
    Project = var.project_name
  }
}
