#!/bin/bash

set -e

export PAGER=cat

echo "🗑️  AWS Resource Cleanup Script"
echo "==============================="
echo ""
echo "⚠️  WARNING: This will delete ALL Astound scraper resources in AWS!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r confirmation

AWS_REGION="us-east-1"
PROJECT="astound-scraper"
ENV="prod"

echo ""
echo "🔍 Deleting resources..."

# Delete Lambda function
echo "• Deleting Lambda function..."
aws lambda delete-function --function-name "${PROJECT}-scraper-${ENV}" --region "$AWS_REGION" 2>/dev/null || echo "  (Lambda not found or already deleted)"

# Delete CloudWatch Log Group
echo "• Deleting CloudWatch log group..."
aws logs delete-log-group --log-group-name "/aws/lambda/${PROJECT}-scraper-${ENV}" --region "$AWS_REGION" 2>/dev/null || echo "  (Log group not found)"

# Delete EventBridge rule targets and rule
echo "• Deleting EventBridge rule..."
aws events remove-targets --rule "${PROJECT}-schedule-${ENV}" --ids lambda --region "$AWS_REGION" 2>/dev/null || true
aws events delete-rule --name "${PROJECT}-schedule-${ENV}" --region "$AWS_REGION" 2>/dev/null || echo "  (EventBridge rule not found)"

# Delete CloudWatch alarm
echo "• Deleting CloudWatch alarm..."
aws cloudwatch delete-alarms --alarm-names "${PROJECT}-lambda-errors-${ENV}" --region "$AWS_REGION" 2>/dev/null || echo "  (Alarm not found)"

# Delete SNS topic
echo "• Deleting SNS topic..."
TOPIC_ARN=$(aws sns list-topics --region "$AWS_REGION" --query "Topics[?contains(TopicArn, '${PROJECT}-alerts-${ENV}')].TopicArn" --output text 2>/dev/null)
if [ -n "$TOPIC_ARN" ]; then
    aws sns delete-topic --topic-arn "$TOPIC_ARN" --region "$AWS_REGION" 2>/dev/null || echo "  (SNS topic delete failed)"
fi

# Delete IAM role policies and role
echo "• Deleting IAM role..."
aws iam delete-role-policy --role-name "${PROJECT}-lambda-role-${ENV}" --policy-name "${PROJECT}-lambda-policy" --region "$AWS_REGION" 2>/dev/null || true
aws iam detach-role-policy --role-name "${PROJECT}-lambda-role-${ENV}" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" --region "$AWS_REGION" 2>/dev/null || true
aws iam delete-role --role-name "${PROJECT}-lambda-role-${ENV}" --region "$AWS_REGION" 2>/dev/null || echo "  (IAM role not found)"

# Delete all ECR images then repository
echo "• Deleting ECR repository..."
aws ecr batch-delete-image --repository-name "${PROJECT}-lambda" --region "$AWS_REGION" \
    --image-ids "$(aws ecr list-images --repository-name "${PROJECT}-lambda" --region "$AWS_REGION" --query 'imageIds[*]' --output json 2>/dev/null)" 2>/dev/null || true
aws ecr delete-repository --repository-name "${PROJECT}-lambda" --region "$AWS_REGION" --force 2>/dev/null || echo "  (ECR repository not found)"

# Empty and delete S3 bucket
echo "• Deleting S3 bucket..."
aws s3 rm "s3://${PROJECT}-data-${ENV}" --recursive --region "$AWS_REGION" 2>/dev/null || true
aws s3api delete-bucket --bucket "${PROJECT}-data-${ENV}" --region "$AWS_REGION" 2>/dev/null || echo "  (S3 bucket not found)"

# Delete Secrets Manager secret
echo "• Deleting Secrets Manager secret..."
SECRET_ARN=$(aws secretsmanager list-secrets --region "$AWS_REGION" --query "SecretList[?contains(Name, '${PROJECT}-credentials-${ENV}')].ARN" --output text 2>/dev/null)
if [ -n "$SECRET_ARN" ]; then
    aws secretsmanager delete-secret --secret-id "$SECRET_ARN" --region "$AWS_REGION" --force-delete-without-recovery 2>/dev/null || echo "  (Secret delete failed)"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Now run: ./deploy.sh"

