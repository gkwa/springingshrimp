output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.scraper.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.scraper.arn
}

output "lambda_image_uri" {
  description = "Current Lambda function image URI"
  value       = aws_lambda_function.scraper.image_uri
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.data_storage.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.data_storage.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.lambda.repository_url
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "ssm_username_parameter" {
  description = "SSM parameter name for username"
  value       = aws_ssm_parameter.astound_username.name
}

output "ssm_password_parameter" {
  description = "SSM parameter name for password"
  value       = aws_ssm_parameter.astound_password.name
  sensitive   = true
}

output "current_image_tag" {
  description = "Current deployed image tag"
  value       = var.image_tag
}
