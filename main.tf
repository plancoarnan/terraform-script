variable "region" {
  description = "The AWS region to deploy to"
  default     = "ap-southeast-1"
}

variable "ecr_image_uri" {
  description = "The URI of the ECR image to use for the Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "api_gateway_name" {
  description = "The name of the API Gateway"
  type        = string
}

variable "existing_iam_role_arn" {
  description = "The ARN of the existing IAM role for the Lambda function"
  type        = string
}

variable "route53_zone_id" {
  description = "The Route 53 Hosted Zone ID"
  type        = string
}

variable "route53_record_name" {
  description = "The Route 53 record name"
  type        = string
}

variable "ecr_repository_name" {
  description = "The name of the ECR repository"
  type        = string
}

variable "new_image_tag" {
  description = "The new image tag to push"
  type        = string
}

provider "aws" {
  region = var.region
}

# Fetch ECR repository details
data "aws_ecr_repository" "my_repo" {
  name = var.ecr_repository_name
}

# Fetch the latest image from the ECR repository
data "aws_ecr_image" "latest_image" {
  repository_name = data.aws_ecr_repository.my_repo.name
  most_recent     = true
}

# Push new image tag
resource "aws_ecr_image" "new_image" {
  repository_name = data.aws_ecr_repository.my_repo.name
  image_tag       = var.new_image_tag
  image_digest    = data.aws_ecr_image.latest_image.image_digest
}

# Lambda function
resource "aws_lambda_function" "my_lambda_function" {
  function_name     = var.lambda_function_name
  image_uri         = var.ecr_image_uri
  package_type      = "Image"
  role              = var.existing_iam_role_arn
  timeout           = 30

  lifecycle {
    ignore_changes = [
      image_uri,
    ]
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = var.api_gateway_name
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

# Route 53 CNAME Record
resource "aws_route53_record" "api_gateway_record" {
  zone_id = var.route53_zone_id
  name    = var.route53_record_name
  type    = "CNAME"
  ttl     = 300

  records = [aws_apigatewayv2_api.http_api.api_endpoint]
}

output "api_endpoint" {
  description = "The HTTP API endpoint"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "latest_image_tag" {
  description = "The latest image tag"
  value       = data.aws_ecr_image.latest_image.image_tag
}

output "new_image_tag" {
  description = "The new image tag"
  value       = aws_ecr_image.new_image.image_tag
}
