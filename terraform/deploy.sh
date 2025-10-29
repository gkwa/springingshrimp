#!/bin/bash

set -e

echo "🚀 Starting Astound Scraper Lambda Deployment"
echo "============================================="

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: Please run this script from the terraform directory"
    exit 1
fi

# Initialize fastplay submodule if not already done
if [ ! -f "../fastplay/package.json" ]; then
    echo "📦 Initializing fastplay submodule..."
    cd ..
    git submodule update --init --recursive
    cd terraform
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ Error: terraform.tfvars not found"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || {
    echo "❌ terraform is required but not installed."
    exit 1
}
command -v docker >/dev/null 2>&1 || {
    echo "❌ docker is required but not installed."
    exit 1
}
command -v aws >/dev/null 2>&1 || {
    echo "❌ aws CLI is required but not installed."
    exit 1
}

# Get AWS region from terraform.tfvars
AWS_REGION=$(grep aws_region terraform.tfvars | cut -d'"' -f2)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
fi

echo ""
echo "📋 Configuration:"
echo "   AWS Region: $AWS_REGION"
echo ""

# Step 1: Terraform Init
echo "1️⃣  Initializing Terraform..."
terraform init -upgrade

# Step 2: Terraform Apply
echo ""
echo "2️⃣  Applying Terraform configuration..."
terraform apply -auto-approve

# Step 3: Get outputs
echo ""
echo "3️⃣  Getting Terraform outputs..."
ECR_URL=$(terraform output -raw ecr_repository_url)
FUNCTION_NAME=$(terraform output -raw lambda_function_name)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo "   ECR Repository: $ECR_URL"
echo "   Lambda Function: $FUNCTION_NAME"
echo "   S3 Bucket: $S3_BUCKET"

# Step 4: Build and push Docker image
echo ""
echo "4️⃣  Building and pushing Docker image..."

# Authenticate to ECR
echo "   Authenticating to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"

# Build the image from parent directory (springingshrimp root)
echo "   Building Docker image..."
cd ..
docker build --platform linux/amd64 -f lambda/Dockerfile -t "$ECR_URL:latest" .

# Push the image
echo "   Pushing Docker image to ECR..."
docker push "$ECR_URL:latest"

# Step 5: Update Lambda function
cd terraform
echo ""
echo "5️⃣  Updating Lambda function code..."
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --image-uri "$ECR_URL:latest" \
    --region "$AWS_REGION"

# Wait for update to complete
echo "   Waiting for Lambda update to complete..."
aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION"

# Step 6: Test the function
echo ""
echo "6️⃣  Testing Lambda function..."
aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --log-type Tail \
    /tmp/lambda-response.json \
    --query 'LogResult' \
    --output text | base64 -d

echo ""
echo "   Response:"
jq </tmp/lambda-response.json
rm /tmp/lambda-response.json

# Success!
echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Next steps:"
echo "   • View logs: aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo "   • View S3 data: aws s3 ls s3://$S3_BUCKET/data/ --recursive"
echo "   • Manual invoke: aws lambda invoke --function-name $FUNCTION_NAME /tmp/response.json"
echo ""

