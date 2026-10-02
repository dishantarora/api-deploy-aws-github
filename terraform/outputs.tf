output "api_url" {
  description = "Base URL of the environment's API Gateway HTTP API."
  value       = module.api.api_url
}

output "items_table_name" {
  description = "DynamoDB table name for this environment."
  value       = module.api.items_table_name
}

output "lambda_function_name" {
  description = "Lambda function name for this environment."
  value       = module.api.lambda_function_name
}
