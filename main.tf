variable "region" {
  description = "The AWS region to deploy to"
  default     = "ap-southeast-1"
}

variable "ecr_image_uri" {
  description = "The URI of the ECR image to use for the Lambda function"
  type        = string
  default = "200262187471.dkr.ecr.ap-southeast-1.amazonaws.com/everestappdcebfd55/nextappstackfunctione45a3c19repo:nextappstackfunction-0eed6328b9db-v1"
}


provider "aws" {
  region = var.region
}

# Lambda IAM role
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach the AWSLambdaBasicExecutionRole to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_basic_exec_role_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "my_lambda_function" {
  function_name     = "my_container_lambda"
  image_uri         = var.ecr_image_uri
  package_type      = "Image"
  role              = aws_iam_role.lambda_exec_role.arn
  timeout           = 30

  lifecycle {
    ignore_changes = [
      image_uri,
    ]
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "my_http_api"
  protocol_type = "HTTP"
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.my_lambda_function.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_endpoint" {
  description = "The HTTP API endpoint"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

