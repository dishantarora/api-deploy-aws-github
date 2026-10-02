variable "environment_name" {
  description = "Short environment label used in resource names and tags."
  type        = string
}

variable "aws_partition" {
  description = "AWS partition name for constructing managed policy ARNs."
  type        = string
}

variable "lambda_source_dir" {
  description = "Path to the Node.js Lambda source directory."
  type        = string
}
