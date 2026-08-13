variable "project_name" {
  description = "Name used to tag and name RDS resources."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the database subnet group."
  type        = list(string)
}

variable "database_sg_id" {
  description = "Security group ID for the database."
  type        = string
}

variable "common_tags" {
  description = "Standard tags applied to taggable resources in this module."
  type        = map(string)
  default     = {}
}

variable "db_name" {
  description = "Initial MySQL database name."
  type        = string
}

variable "db_username" {
  description = "Initial MySQL username."
  type        = string
}

variable "db_password" {
  description = "Initial MySQL password. Provide securely outside Git."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance size."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated database storage in GB."
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}

variable "delete_automated_backups" {
  description = "Whether to delete automated backups when the demo database is destroyed."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip a final snapshot when destroying the database."
  type        = bool
  default     = true
}
