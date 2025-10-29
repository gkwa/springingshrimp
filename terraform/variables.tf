variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "astound-scraper"
}

variable "astound_username" {
  description = "Astound Broadband username"
  type        = string
  sensitive   = true
}

variable "astound_password" {
  description = "Astound Broadband password"
  type        = string
  sensitive   = true
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (e.g., 'rate(1 hour)' or 'cron(0 12 * * ? *)')"
  type        = string
  default     = "cron(0 16 * * ? *)" # Daily at 9 AM PDT (4 PM UTC)
}

variable "schedule_enabled" {
  description = "Whether the schedule is enabled"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Number of days to retain data in S3"
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "alert_email" {
  description = "Email address for alerts (leave empty to disable)"
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "git_branch" {
  description = "Git branch to build from"
  type        = string
  default     = "master"
}
