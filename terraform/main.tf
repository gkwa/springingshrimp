terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "astound-scraper"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# S3 bucket for storing scraped data
resource "aws_s3_bucket" "data_storage" {
  bucket = "${var.project_name}-data-${var.environment}"
}

resource "aws_s3_bucket_versioning" "data_storage" {
  bucket = aws_s3_bucket.data_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_storage" {
  bucket = aws_s3_bucket.data_storage.id

  rule {
    id     = "delete-old-data"
    status = "Enabled"

    expiration {
      days = var.data_retention_days
    }
  }
}

# Secrets Manager for Astound credentials
resource "aws_secretsmanager_secret" "astound_credentials" {
  name                    = "${var.project_name}-credentials-${var.environment}"
  description             = "Astound Broadband login credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "astound_credentials" {
  secret_id = aws_secretsmanager_secret.astound_credentials.id
  secret_string = jsonencode({
    username = var.astound_username
    password = var.astound_password
  })
}

# ECR repository for Lambda container image
resource "aws_ecr_repository" "lambda" {
  name                 = "${var.project_name}-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "lambda" {
  repository = aws_ecr_repository.lambda.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role-${var.environment}"

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

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for S3 and Secrets Manager access
resource "aws_iam_role_policy" "lambda_custom" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_storage.arn,
          "${aws_s3_bucket.data_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.astound_credentials.arn
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "scraper" {
  function_name = "${var.project_name}-scraper-${var.environment}"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda.repository_url}:latest"
  timeout       = 300  # 5 minutes
  memory_size   = 2048 # Playwright needs memory

  environment {
    variables = {
      S3_BUCKET          = aws_s3_bucket.data_storage.id
      SECRET_ARN         = aws_secretsmanager_secret.astound_credentials.arn
      ASTOUND_CONFIG     = "prod"
      NODE_ENV           = var.environment
    }
  }

  ephemeral_storage {
    size = 2048 # MB (Chromium needs space)
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_custom
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.scraper.function_name}"
  retention_in_days = var.log_retention_days
}

# EventBridge rule for scheduled execution
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.project_name}-schedule-${var.environment}"
  description         = "Trigger Astound scraper on schedule"
  schedule_expression = var.schedule_expression
  is_enabled          = var.schedule_enabled
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.scraper.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scraper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

# SNS topic for alerts (optional)
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Lambda function errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.scraper.function_name
  }
}

