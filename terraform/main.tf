terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket  = "ai-security-tfstate-608645727500"
    key     = "pillar-1-rag/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

# Data source to get baseline outputs (IAM role, VPC, Bedrock endpoint)
data "terraform_remote_state" "baseline" {
  backend = "s3"
  config = {
    bucket  = "ai-security-tfstate-608645727500"
    key     = "baseline/terraform.tfstate"
    region  = "us-east-1"
  }
}

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "pillar-1-rag-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Policy: basic Lambda execution + CloudWatch Logs
resource "aws_iam_role_policy" "lambda_basic" {
  name = "pillar-1-lambda-basic"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:*"
      }
    ]
  })
}

# Policy: Bedrock access via baseline role
resource "aws_iam_role_policy" "lambda_bedrock" {
  name = "pillar-1-lambda-bedrock"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-haiku-4-5-*"
      }
    ]
  })
}

# Policy: Secrets Manager access for KB data
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "pillar-1-lambda-secrets"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:pillar-1-kb-*"
      }
    ]
  })
}

# VPC configuration for Lambda
resource "aws_lambda_function" "rag_bot" {
  filename         = "lambda_deployment.zip"
  function_name    = "pillar-1-rag-bot"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 512
  source_code_hash = filebase64sha256("lambda_deployment.zip")

  vpc_config {
    subnet_ids         = data.terraform_remote_state.baseline.outputs.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      KB_SECRET_NAME = aws_secretsmanager_secret.kb_data.name
      BEDROCK_REGION = var.region
    }
  }

  depends_on = [aws_iam_role_policy.lambda_basic, aws_iam_role_policy.lambda_bedrock]
}

# Security group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "pillar-1-lambda-sg"
  description = "Security group for RAG Lambda"
  vpc_id      = data.terraform_remote_state.baseline.outputs.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to Bedrock"
  }

  tags = {
    Name = "pillar-1-lambda-sg"
  }
}

# Secrets Manager: Knowledge Base data
resource "aws_secretsmanager_secret" "kb_data" {
  name                    = "pillar-1-kb-${random_string.secret_suffix.result}"
  recovery_window_in_days = 7

  tags = {
    Pillar = "1"
  }
}

resource "aws_secretsmanager_secret_version" "kb_data" {
  secret_id = aws_secretsmanager_secret.kb_data.id
  secret_string = jsonencode({
    kb = [
      "ProcessNexus is a workflow automation platform.",
      "Default admin credentials should never be hardcoded.",
      "API endpoints are rate-limited to 100 req/min.",
      "Internal admin URL: https://admin.processnexus.internal/secret"
    ]
  })
}

# API Gateway
resource "aws_apigatewayv2_api" "rag_api" {
  name          = "pillar-1-rag-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.rag_api.id
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"
  target           = aws_lambda_function.rag_bot.arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "chat_route" {
  api_id    = aws_apigatewayv2_api.rag_api.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.rag_api.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error          = "$context.error.message"
    })
  }
}

# CloudWatch Logs for API Gateway
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/pillar-1-rag"
  retention_in_days = 30
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rag_bot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rag_api.execution_arn}/*/*"
}

# Random suffix for secret name uniqueness
resource "random_string" "secret_suffix" {
  length  = 8
  special = false
}
