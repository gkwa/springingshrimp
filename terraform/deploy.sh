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
command -v aws >/dev/null 2>&1 || {
    echo "❌ aws CLI is required but not installed."
    exit 1
}
command -v git >/dev/null 2>&1 || {
    echo "❌ git is required but not installed."
    exit 1
}
command -v jq >/dev/null 2>&1 || {
    echo "❌ jq is required but not installed."
    exit 1
}

# Get AWS region from terraform.tfvars
AWS_REGION=$(grep aws_region terraform.tfvars | cut -d'"' -f2)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
fi

# Auto-detect current git branch, or allow override via argument
cd ..
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
cd terraform
GIT_BRANCH="${1:-$CURRENT_BRANCH}"

echo ""
echo "📋 Configuration:"
echo "   AWS Region: $AWS_REGION"
echo "   Git Branch: $GIT_BRANCH"

# Step 1: Terraform Init
echo ""
echo "1️⃣  Initializing Terraform..."
terraform init -upgrade

# Step 2: Apply infrastructure (ECR, CodeBuild, etc.) without Lambda
echo ""
echo "2️⃣  Ensuring infrastructure exists (ECR, CodeBuild)..."
terraform apply \
    -target=aws_ecr_repository.lambda \
    -target=aws_ecr_lifecycle_policy.lambda \
    -target=aws_iam_role.codebuild \
    -target=aws_iam_role_policy.codebuild \
    -target=aws_codebuild_project.lambda_builder \
    -var="git_branch=$GIT_BRANCH" \
    -auto-approve

# Step 3: Get ECR URL and CodeBuild project name
echo ""
echo "3️⃣  Getting infrastructure details..."
ECR_URL=$(terraform output -raw ecr_repository_url)
CODEBUILD_PROJECT=$(terraform output -raw codebuild_project_name)
echo "   ECR Repository: $ECR_URL"
echo "   CodeBuild Project: $CODEBUILD_PROJECT"

# Step 4: Trigger CodeBuild to build and push Docker image
echo ""
echo "4️⃣  Triggering CodeBuild to build Docker image from branch: $GIT_BRANCH..."
BUILD_ID=$(aws codebuild start-build \
    --project-name "$CODEBUILD_PROJECT" \
    --region "$AWS_REGION" \
    --source-version "refs/heads/$GIT_BRANCH" \
    --query 'build.id' \
    --output text)

echo "   Build ID: $BUILD_ID"
echo "   Waiting for build to complete..."

# Wait for build to complete
while true; do
    BUILD_STATUS=$(aws codebuild batch-get-builds \
        --ids "$BUILD_ID" \
        --region "$AWS_REGION" \
        --query 'builds[0].buildStatus' \
        --output text)

    if [ "$BUILD_STATUS" = "SUCCEEDED" ]; then
        echo "   ✅ Build succeeded!"
        break
    elif [ "$BUILD_STATUS" = "FAILED" ] || [ "$BUILD_STATUS" = "FAULT" ] || [ "$BUILD_STATUS" = "TIMED_OUT" ] || [ "$BUILD_STATUS" = "STOPPED" ]; then
        echo "   ❌ Build failed with status: $BUILD_STATUS"
        echo ""
        echo "View build logs:"
        echo "   aws logs tail /aws/codebuild/$CODEBUILD_PROJECT --follow"
        exit 1
    fi

    echo "   Status: $BUILD_STATUS (waiting...)"
    sleep 10
done

# Get the image tag from build output
echo ""
echo "5️⃣  Getting image tag from build..."
BUILD_ARTIFACTS=$(aws codebuild batch-get-builds \
    --ids "$BUILD_ID" \
    --region "$AWS_REGION" \
    --query 'builds[0].environment.environmentVariables[?name==`IMAGE_TAG`].value' \
    --output text)

if [ -z "$BUILD_ARTIFACTS" ]; then
    echo "   ⚠️  Could not extract IMAGE_TAG from build, using 'latest'"
    IMAGE_TAG="latest"
else
    IMAGE_TAG="$BUILD_ARTIFACTS"
fi

echo "   Image Tag: $IMAGE_TAG"

# Step 6: Apply Terraform with the specific image tag
echo ""
echo "6️⃣  Deploying Lambda with image tag: $IMAGE_TAG..."
terraform apply -var="image_tag=$IMAGE_TAG" -var="git_branch=$GIT_BRANCH" -auto-approve

# Step 7: Get all outputs
echo ""
echo "7️⃣  Getting Terraform outputs..."
FUNCTION_NAME=$(terraform output -raw lambda_function_name)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
DEPLOYED_IMAGE=$(terraform output -raw lambda_image_uri)

echo "   Lambda Function: $FUNCTION_NAME"
echo "   S3 Bucket: $S3_BUCKET"
echo "   Deployed Image: $DEPLOYED_IMAGE"

# Step 8: Test the function
echo ""
echo "8️⃣  Testing Lambda function..."
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
echo "   • Branch: $GIT_BRANCH"
echo "   • Image Tag: $IMAGE_TAG"
echo "   • Build ID: $BUILD_ID"
echo ""
echo "📊 Next steps:"
echo "   • View logs: aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo "   • View S3 data: aws s3 ls s3://$S3_BUCKET/data/ --recursive"
echo "   • Manual invoke: aws lambda invoke --function-name $FUNCTION_NAME /tmp/response.json"
echo "   • View build logs: aws logs tail /aws/codebuild/$CODEBUILD_PROJECT --follow"
echo ""
