variable "aws_region" {
  description = "Region in which to create the Terraform state bucket."
  type        = string
}

variable "bucket_prefix" {
  description = "Unique project prefix for the versioned Terraform state bucket."
  type        = string
  default     = "api-deploy-tfstate"
}
