terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "image-generate"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}

resource "aws_dynamodb_table" "profile" {
  name           = "profile"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "profileId"

  attribute {
    name = "profileId"
    type = "S"
  }

}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/python/"
  output_path = "${path.module}/python/lambda_function.zip"
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name          = "imageGenerator-lambda"
  description            = "My lambda function"
  handler                = "lambda_function.lambda_handler"
  runtime                = "python3.9"
  memory_size            = 512
  timeout                = 15
  ephemeral_storage_size = 1024
  layers                 = [var.layer_lambda_pillow]

  source_path = "${path.module}/python/"

  tags = {
    Name = "terraform-imageGenerator-lambda"
  }
}

resource "aws_apigatewayv2_api" "api" {
  name          = "imageGenerator-API"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins  = ["*"]
    allow_methods  = ["*"]
    allow_headers  = ["*"]
    expose_headers = ["*"]
  }
}


resource "aws_apigatewayv2_stage" "apigateway" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each           = local.routes
  api_id             = aws_apigatewayv2_api.api.id
  integration_uri    = module.lambda_function.lambda_function_arn
  integration_type   = "HTTP_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda["index"].id}"
}

resource "aws_apigatewayv2_route" "lambda" {
  for_each  = local.routes
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "${each.value.http_verb} ${each.value.path}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.value.name].id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.api.name}"
  retention_in_days = 1
}