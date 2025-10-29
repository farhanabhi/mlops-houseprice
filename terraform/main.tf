terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_id" "suffix" {
  byte_length = 3
}

# S3 bucket for artifacts
resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "houseprice-artifacts-${random_id.suffix.hex}"
  force_destroy = true
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "houseprice-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function (placeholder)
resource "aws_lambda_function" "predictor" {
  filename         = "lambda.zip"
  function_name    = "houseprice-predictor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      MODEL_S3_BUCKET = aws_s3_bucket.artifact_bucket.bucket
    }
  }
}

# API Gateway for public access
resource "aws_apigatewayv2_api" "api" {
  name          = "HousePriceAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.predictor.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /predict"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# Give permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.predictor.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}
