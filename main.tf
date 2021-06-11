# Setting up version constraints. 
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      version = ">= 3.44.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.key_id
  secret_key = var.key_secret
}

# Creating IAM role for Lambda to READ DynamoDB tables

resource "aws_iam_role" "dynamodb_ro_lambda" {
  name               = "dynamodb_ro_lambda"
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

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"]
}

# Creating DynamoDB table

resource "aws_dynamodb_table" "test_table" {
  name           = "words"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "word"

  attribute {
    name = "word"
    type = "S"
  }

}

# Filling the table with values

resource "aws_dynamodb_table_item" "test_table_items" {
  table_name = aws_dynamodb_table.test_table.name
  hash_key   = aws_dynamodb_table.test_table.hash_key

  for_each = var.words

  item = <<ITEM
{
  "word": {"S": "${each.value.word}"}
}
ITEM
}

# Creating Lambda function

resource "aws_lambda_function" "test_lambda" {
  filename         = "lambda_function.zip"
  function_name    = "test_lambda_dynamodb"
  role             = aws_iam_role.dynamodb_ro_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("lambda_function.zip")

  runtime = "python3.7"

}


resource "aws_apigatewayv2_api" "test_gateway" {
  name                       = "test-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}


resource "aws_apigatewayv2_route" "test_gateway_route" {
  api_id                              = aws_apigatewayv2_api.test_gateway.id
  route_key                           = "$default"
  target                              = "integrations/${aws_apigatewayv2_integration.test_gateway_integration.id}"
  route_response_selection_expression = "$default"
}

resource "aws_apigatewayv2_integration" "test_gateway_integration" {
  api_id           = aws_apigatewayv2_api.test_gateway.id
  integration_type = "AWS_PROXY"

  #connection_type           = "INTERNET"
  #content_handling_strategy = "CONVERT_TO_TEXT"
  #description               = "Lambda example"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.test_lambda.invoke_arn
  #passthrough_behavior      = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_integration_response" "test_gateway_integration_response" {
  api_id                   = aws_apigatewayv2_api.test_gateway.id
  integration_id           = aws_apigatewayv2_integration.test_gateway_integration.id
  integration_response_key = "$default"
}


resource "aws_apigatewayv2_route_response" "test_gateway_route_response" {
  api_id             = aws_apigatewayv2_api.test_gateway.id
  route_id           = aws_apigatewayv2_route.test_gateway_route.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_deployment" "test_api_deployment" {
  api_id      = aws_apigatewayv2_route.test_gateway_route.api_id
  description = "Example deployment"
}

resource "aws_apigatewayv2_stage" "test_stage" {
  api_id        = aws_apigatewayv2_api.test_gateway.id
  name          = "test"
  deployment_id = aws_apigatewayv2_deployment.test_api_deployment.id
}


resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.test_gateway.execution_arn}/*/*"
}
