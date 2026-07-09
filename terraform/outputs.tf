output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.rag_api.api_endpoint
}

output "chat_url" {
  description = "Full URL for chat endpoint"
  value       = "${aws_apigatewayv2_api.rag_api.api_endpoint}/prod/chat"
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.rag_bot.function_name
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_role.arn
}

output "kb_secret_name" {
  description = "Secrets Manager secret name for KB data"
  value       = aws_secretsmanager_secret.kb_data.name
}
