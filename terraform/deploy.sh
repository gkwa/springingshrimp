#!/bin/bash

set -e

export PAGER=cat

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
command -v git >/dev/null 2>&1 || {
    echo "❌ git is required but not installed."
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

# Generate immutable image tag: git-sha + timestamp
cd ..
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_TAG="${GIT_SHA}-${TIMESTAMP}"
cd terraform

echo "   Image Tag: $IMAGE_TAG"
echo ""

# Step 1: Terraform Init
echo "1️⃣  Initializing Terraform..."
terraform init -upgrade

# Step 2: Apply ONLY the ECR repository first (if it doesn't exist)
echo ""
echo "2️⃣  Ensuring ECR repository exists..."
terraform apply -target=aws_ecr_repository.lambda -target=aws_ecr_lifecycle_policy.lambda -auto-approve

# Step 3: Get ECR URL
echo ""
echo "3️⃣  Getting ECR repository URL..."
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "   ECR Repository: $ECR_URL"

# Step 4: Build and push Docker image with immutable tag
echo ""
echo "4️⃣  Building and pushing Docker image..."

# Authenticate to ECR
echo "   Authenticating to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"

# Build the image from parent directory (springingshrimp root)
echo "   Building Docker image..."
cd ..
docker build --platform linux/amd64 -f lambda/Dockerfile -t "$ECR_URL:$IMAGE_TAG" -t "$ECR_URL:latest" .

# Push both the immutable tag and latest
echo "   Pushing Docker image to ECR..."
docker push "$ECR_URL:$IMAGE_TAG"
docker push "$ECR_URL:latest"

echo "   ✅ Pushed: $ECR_URL:$IMAGE_TAG"
echo "   ✅ Pushed: $ECR_URL:latest"

# Step 5: Apply Terraform with the specific image tag
cd terraform
echo ""
echo "5️⃣  Applying Terraform configuration with image tag: $IMAGE_TAG..."
terraform apply -var="image_tag=$IMAGE_TAG" -auto-approve

# Step 6: Get all outputs
echo ""
echo "6️⃣  Getting Terraform outputs..."
FUNCTION_NAME=$(terraform output -raw lambda_function_name)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
DEPLOYED_IMAGE=$(terraform output -raw lambda_image_uri)

echo "   Lambda Function: $FUNCTION_NAME"
echo "   S3 Bucket: $S3_BUCKET"
echo "   Deployed Image: $DEPLOYED_IMAGE"

# Step 7: Test the function
echo ""
echo "7️⃣  Testing Lambda function..."
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
echo "📊 Deployment Details:"
echo "   • Image Tag: $IMAGE_TAG"
echo "   • Git SHA: $GIT_SHA"
echo "   • Timestamp: $TIMESTAMP"
echo ""
echo "📊 Next steps:"
echo "   • View logs: aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo "   • View S3 data: aws s3 ls s3://$S3_BUCKET/data/ --recursive"
echo "   • Manual invoke: aws lambda invoke --function-name $FUNCTION_NAME /tmp/response.json"
echo ""
