variable "project_name" {
  description = "Name used to tag and name VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "common_tags" {
  description = "Standard tags applied to taggable resources in this module."
  type        = map(string)
  default     = {}
}
