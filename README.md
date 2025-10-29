# Springingshrimp - Astound Scraper AWS Lambda Deployment 🚀

AWS Lambda deployment infrastructure for the [fastplay](https://github.com/gkwa/fastplay) Astound Broadband data usage scraper.

## Overview

This repository contains the AWS infrastructure code to deploy the fastplay scraper as a serverless Lambda function that runs daily at 9 AM UTC.

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
- **ECR Repository**: Docker image storage
- **S3 Bucket**: Organized data storage with lifecycle policies
- **Secrets Manager**: Secure credential storage
- **EventBridge**: Daily 9 AM UTC schedule
- **CloudWatch**: Logs, metrics, and alarms
- **SNS**: Email notifications (optional)
- **IAM Roles**: Minimal required permissions

**Cost**: ~$7-12/month

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

Default: **Daily at 9 AM UTC**

To change timezone, edit `terraform/terraform.tfvars`:
```hcl
# 9 AM PST = 5 PM UTC
schedule_expression = "cron(0 17 * * ? *)"

# 9 AM EST = 2 PM UTC
schedule_expression = "cron(0 14 * * ? *)"

# Every 6 hours
schedule_expression = "cron(0 */6 * * ? *)"
```

Then apply: `cd terraform && terraform apply`

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

- ✅ Credentials encrypted in AWS Secrets Manager
- ✅ S3 bucket private by default
- ✅ IAM role with minimal permissions
- ✅ No secrets in logs

## Links

- [Fastplay Repository](https://github.com/gkwa/fastplay) - Core scraper
- [Terraform Docs](terraform/README.md) - Detailed infrastructure docs

## License

ISC
