# Astound Scraper - AWS Lambda Deployment 🚀

Complete Terraform infrastructure for deploying the Astound Broadband data usage scraper to AWS Lambda.

## ✨ Features

- 🔄 **Automated Scheduling**: Runs every 6 hours (customizable)
- 🔒 **Secure**: Credentials in AWS Secrets Manager
- 📦 **Organized Storage**: Data organized by date in S3
- 📊 **Monitoring**: CloudWatch logs and alarms with email alerts
- 💰 **Cost-Effective**: ~$7-12/month
- 🎯 **Easy Deployment**: One-command deployment script
- 🧪 **Local Testing**: Test before deploying to AWS

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured
- Terraform installed (>= 1.0)
- Docker installed and running

### 1. Configure
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Astound credentials
```

### 2. Deploy
```bash
chmod +x deploy.sh
./deploy.sh
```

### 3. Monitor
```bash
make logs          # View Lambda logs
make s3-list       # List scraped data
make s3-sync       # Download data
```

## 📦 What Gets Deployed

- **Lambda Function**: Containerized Playwright scraper (2GB, 5min timeout)
- **ECR Repository**: Docker image storage
- **S3 Bucket**: Organized data storage with lifecycle policies
- **Secrets Manager**: Secure credential storage
- **EventBridge**: Automatic scheduling
- **CloudWatch**: Logs, metrics, and alarms
- **SNS**: Email notifications
- **IAM Roles**: Minimal required permissions

## 💰 Cost: ~$7-12/month

## 📚 Documentation

- [Quick Start](terraform/QUICKSTART.md) - 5-minute setup
- [Detailed Guide](terraform/README.md) - Complete documentation
- [Architecture](terraform/ARCHITECTURE.md) - System diagrams
- [Overview](terraform/OVERVIEW.md) - Features and structure

## 🎮 Usage

### Make Commands (Recommended)
```bash
make help          # Show all commands
make deploy        # Full deployment
make logs          # View logs
make invoke        # Manual test
make s3-list       # List data
make destroy       # Remove all
```

### Deployment Scripts
```bash
cd terraform
./deploy.sh        # Automated deployment
./test-local.sh    # Local testing
```

## 🔧 Configuration

Edit `terraform/terraform.tfvars`:
```hcl
# Schedule options
schedule_expression = "cron(0 */6 * * ? *)"  # Every 6 hours
schedule_expression = "cron(0 6 * * ? *)"    # Daily at 6 AM
schedule_expression = "rate(1 hour)"         # Every hour

# Data retention
data_retention_days = 90
log_retention_days = 30

# Email alerts
alert_email = "you@example.com"
```

## 🧪 Local Testing
```bash
cd terraform
./test-local.sh
```

## 📊 Monitoring
```bash
# Real-time logs
make logs

# List data in S3
make s3-list

# Download all data
make s3-sync
```

## 🗑️ Cleanup
```bash
make s3-sync       # Backup data first
make destroy       # Remove all resources
```

## 🔐 Security

- ✅ Credentials encrypted in Secrets Manager
- ✅ S3 bucket private by default
- ✅ IAM role with minimal permissions
- ✅ No secrets in logs

## 📂 Project Structure
```
.
├── README.md              # This file
├── Makefile               # Convenience commands
├── terraform/             # Infrastructure code
│   ├── main.tf           # AWS resources
│   ├── deploy.sh         # Deployment script
│   └── *.md              # Documentation
└── lambda/                # Application code
    ├── Dockerfile        # Container image
    ├── index.ts          # Lambda handler
    └── S3FileManager.ts  # S3 operations
```

## 🎯 Next Steps

1. Read [terraform/QUICKSTART.md](terraform/QUICKSTART.md)
2. Configure `terraform/terraform.tfvars`
3. Run `cd terraform && ./deploy.sh`
4. Monitor with `make logs`
