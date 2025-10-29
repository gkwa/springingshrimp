# Springingshrimp - Astound Scraper AWS Lambda Deployment 🚀

AWS Lambda deployment infrastructure for the [fastplay](https://github.com/gkwa/fastplay) Astound Broadband data usage scraper.

## Overview

This repository contains the AWS infrastructure code to deploy the fastplay scraper as a serverless Lambda function that runs daily at 9 AM PDT (4 PM UTC).

## Prerequisites

- AWS CLI configured
- Terraform installed (>= 1.0)
- Docker installed and running
- Git

## Quick Start

### 1. Clone with Submodule

```bash
git clone --recurse-submodules https://github.com/yourusername/springingshrimp.git
cd springingshrimp
```

Or if already cloned:

```bash
git submodule add https://github.com/gkwa/fastplay.git fastplay
git submodule update --init --recursive
```

### 2. Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Astound credentials
```

### 3. Deploy

```bash
make deploy
```

### 4. Monitor

```bash
make logs          # View Lambda logs
make s3-list       # List scraped data
make s3-sync       # Download data
```

## What Gets Deployed

- **Lambda Function**: Containerized Playwright scraper (2GB, 5min timeout)
- **ECR Repository**: Docker image storage with immutable tags
- **S3 Bucket**: Organized data storage with lifecycle policies
- **SSM Parameter Store**: Secure credential storage (FREE!)
- **EventBridge**: Daily 9 AM PDT schedule
- **CloudWatch**: Logs, metrics, and alarms
- **SNS**: Email notifications (optional)
- **IAM Roles**: Minimal required permissions

**Monthly Cost**: ~$0.11 (just ECR + CloudWatch logs!)

## Commands

```bash
make help           # Show all commands
make submodule-init # Initialize fastplay submodule
make deploy         # Full deployment
make test-local     # Test locally with Docker
make logs           # View Lambda logs
make invoke         # Manual invocation
make s3-list        # List S3 data
make s3-sync        # Download all data
make destroy        # Remove all resources
```

## Schedule Configuration

Default: **Daily at 9 AM PDT (4 PM UTC)**

To change schedule, edit `terraform/terraform.tfvars`:

```hcl
# 9 AM PST (standard time) = 5 PM UTC
schedule_expression = "cron(0 17 * * ? *)"

# 6 AM PDT = 1 PM UTC
schedule_expression = "cron(0 13 * * ? *)"

# Every 6 hours
schedule_expression = "cron(0 */6 * * ? *)"

# Twice daily: 9 AM and 9 PM PDT
# 9 AM PDT = 4 PM UTC, 9 PM PDT = 4 AM UTC (next day)
schedule_expression = "cron(0 4,16 * * ? *)"
```

Then apply: `cd terraform && terraform apply`

**Note**: PDT (Pacific Daylight Time) is UTC-7. When daylight saving ends, you'll need to adjust for PST (UTC-8).

## Project Structure

```
springingshrimp/
├── fastplay/              # Git submodule (core scraper)
├── lambda/                # AWS Lambda specific code
│   ├── Dockerfile        # Container image
│   ├── index.ts          # Lambda handler
│   └── S3FileManager.ts  # S3 operations
├── terraform/             # Infrastructure as Code
│   ├── main.tf           # AWS resources
│   ├── deploy.sh         # Deployment script
│   └── *.tf              # Terraform config
├── Makefile              # Convenience commands
└── README.md             # This file
```

## Updating Fastplay Version

To update to a newer version of fastplay:

```bash
cd fastplay
git pull origin main
cd ..
git add fastplay
git commit -m "Update fastplay submodule"
make deploy
```

## Development

### Test Locally

```bash
make test-local
```

This runs the Lambda function locally using Docker.

### Manual Build

```bash
# From springingshrimp root
docker build --platform linux/amd64 -f lambda/Dockerfile -t test .
```

## Monitoring

### Real-time Logs

```bash
make logs
```

### Check S3 Data

```bash
make s3-list
aws s3 ls s3://astound-scraper-data-prod/data/ --recursive
```

### Download Data

```bash
make s3-sync
# Data saved to ./data-backup/
```

### Manual Invocation

```bash
make invoke
```

## Troubleshooting

### Submodule Not Initialized

```bash
make submodule-init
```

### Docker Build Fails

Ensure you're building from the springingshrimp root directory:

```bash
docker build --platform linux/amd64 -f lambda/Dockerfile -t test .
```

### Lambda Timeout

Increase timeout in `terraform/main.tf`:

```hcl
timeout = 600  # 10 minutes instead of 5
```

### View Detailed Logs

```bash
aws logs tail /aws/lambda/astound-scraper-scraper-prod --follow
```

## Cleanup

```bash
make s3-sync       # Backup data first
make destroy       # Remove all AWS resources
```

## Security

- ✅ Credentials encrypted in SSM Parameter Store
- ✅ S3 bucket private by default
- ✅ IAM role with minimal permissions
- ✅ No secrets in logs
- ✅ Immutable Docker image tags for auditability

## AWS Console Links

### Core Services

- **Lambda Function**: [astound-scraper-scraper-prod](https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions/astound-scraper-scraper-prod)
- **S3 Bucket**: [astound-scraper-data-prod](https://s3.console.aws.amazon.com/s3/buckets/astound-scraper-data-prod?region=us-east-1)
- **ECR Repository**: [astound-scraper-lambda](https://console.aws.amazon.com/ecr/repositories/private/376351446210/astound-scraper-lambda?region=us-east-1)

### Configuration & Secrets

- **SSM Parameter Store**: [View Parameters](https://console.aws.amazon.com/systems-manager/parameters?region=us-east-1&search=/astound-scraper)

### Monitoring & Logging

- **CloudWatch Logs**: [Lambda Log Group](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/$252Faws$252Flambda$252Fastound-scraper-scraper-prod)
- **CloudWatch Alarms**: [Lambda Errors Alarm](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:alarm/astound-scraper-lambda-errors-prod)

### Scheduling & Notifications

- **EventBridge Rule**: [astound-scraper-schedule-prod](https://console.aws.amazon.com/events/home?region=us-east-1#/eventbus/default/rules/astound-scraper-schedule-prod)
- **SNS Topic**: [astound-scraper-alerts-prod](https://console.aws.amazon.com/sns/v3/home?region=us-east-1#/topic/arn:aws:sns:us-east-1:376351446210:astound-scraper-alerts-prod)

### Cost & Billing

- **Cost Explorer**: [View Costs](https://console.aws.amazon.com/cost-management/home?region=us-east-1#/cost-explorer)
- **Billing Dashboard**: [Current Month Bill](https://console.aws.amazon.com/billing/home?region=us-east-1#/bills)

## Links

- [Fastplay Repository](https://github.com/gkwa/fastplay) - Core scraper
- [Terraform Docs](terraform/README.md) - Detailed infrastructure docs

## License

ISC
