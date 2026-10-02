variable "environment_name" {
  description = "Deployment environment whose isolated infrastructure is managed by this state."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "environment_name must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
}
