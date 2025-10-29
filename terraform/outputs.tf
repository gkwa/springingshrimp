output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.scraper.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.scraper.arn
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

output "deployment_instructions" {
  description = "Instructions for deploying the Lambda function"
  value       = <<-EOT
    To deploy your Lambda function:

    1. Build and push the Docker image:
       cd lambda
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.lambda.repository_url}
       docker build --platform linux/amd64 -t ${aws_ecr_repository.lambda.repository_url}:latest .
       docker push ${aws_ecr_repository.lambda.repository_url}:latest

    2. Update the Lambda function:
       aws lambda update-function-code --function-name ${aws_lambda_function.scraper.function_name} --image-uri ${aws_ecr_repository.lambda.repository_url}:latest

    3. Test the function:
       aws lambda invoke --function-name ${aws_lambda_function.scraper.function_name} /tmp/response.json
       cat /tmp/response.json
  EOT
}

