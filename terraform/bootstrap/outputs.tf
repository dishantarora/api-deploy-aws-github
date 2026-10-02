output "state_bucket" {
  description = "S3 bucket for the stage and bootstrap Terraform states."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_region" {
  description = "AWS region containing the S3 state bucket."
  value       = var.aws_region
}
