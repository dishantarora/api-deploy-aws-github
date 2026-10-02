locals {
  function_name = "api-${var.environment_name}"
  table_name    = "api-items-${var.environment_name}"
  common_tags = {
    Application = "api-deploy-aws-github"
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
}

data "archive_file" "lambda_package" {
  type             = "zip"
  source_dir       = var.lambda_source_dir
  output_path      = "${path.root}/lambda-${var.environment_name}.zip"
  output_file_mode = "0666"
  excludes         = ["node_modules/**"]
}

resource "aws_dynamodb_table" "items" {
  name                        = local.table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"
  deletion_protection_enabled = var.environment_name == "prod"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.environment_name == "prod"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda" {
  name = "${local.function_name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "dynamodb_read" {
  name = "${local.function_name}-dynamodb-read"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.items.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${var.aws_partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.environment_name == "prod" ? 90 : 30
  tags              = local.common_tags
}

resource "aws_lambda_function" "api" {
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs24.x"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 10
  publish          = true

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items.name
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy.dynamodb_read,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live API version managed by Terraform."
  function_name    = aws_lambda_function.api.function_name
  function_version = aws_lambda_function.api.version
}

resource "aws_apigatewayv2_api" "http" {
  name          = local.function_name
  protocol_type = "HTTP"
  tags          = local.common_tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_alias.live.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_items" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_item" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items/{itemId}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
  tags        = local.common_tags
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
