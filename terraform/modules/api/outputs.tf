output "api_url" {
  description = "Base URL of the API Gateway HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "items_table_name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.items.name
}

output "lambda_function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.api.function_name
}
