variable "project_name" {
  description = "Name used to tag S3 resources."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "common_tags" {
  description = "Standard tags applied to taggable resources in this module."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "When true, Terraform can delete non-empty demo buckets during destroy."
  type        = bool
  default     = true
}
