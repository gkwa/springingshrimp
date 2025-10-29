.PHONY: help init plan apply deploy test-local logs clean destroy submodule-init

help:
	@echo "Astound Scraper - AWS Lambda Deployment"
	@echo ""
	@echo "Available commands:"
	@echo "  make submodule-init - Initialize fastplay submodule"
	@echo "  make init          - Initialize Terraform"
	@echo "  make plan          - Preview infrastructure changes"
	@echo "  make apply         - Apply infrastructure changes"
	@echo "  make deploy        - Full deployment (infrastructure + Docker image)"
	@echo "  make test-local    - Test Lambda function locally with Docker"
	@echo "  make logs          - Tail Lambda function logs"
	@echo "  make invoke        - Manually invoke Lambda function"
	@echo "  make s3-list       - List scraped data in S3"
	@echo "  make s3-sync       - Download all data from S3"
	@echo "  make clean         - Stop local Docker container"
	@echo "  make destroy       - Destroy all AWS resources"

submodule-init:
	@echo "Initializing fastplay submodule..."
	git submodule update --init --recursive
	@echo "✅ Submodule initialized"

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

deploy: submodule-init
	cd terraform && ./deploy.sh

test-local: submodule-init
	cd terraform && ./test-local.sh

logs:
	@FUNCTION_NAME=$$(cd terraform && terraform output -raw lambda_function_name 2>/dev/null) && \
	if [ -n "$$FUNCTION_NAME" ]; then \
		aws logs tail /aws/lambda/$$FUNCTION_NAME --follow; \
	else \
		echo "Error: Run 'make apply' first to create resources"; \
	fi

invoke:
	@FUNCTION_NAME=$$(cd terraform && terraform output -raw lambda_function_name 2>/dev/null) && \
	if [ -n "$$FUNCTION_NAME" ]; then \
		aws lambda invoke --function-name $$FUNCTION_NAME /tmp/response.json && \
		jq </tmp/response.json && \
		rm /tmp/response.json; \
	else \
		echo "Error: Run 'make apply' first to create resources"; \
	fi

s3-list:
	@S3_BUCKET=$$(cd terraform && terraform output -raw s3_bucket_name 2>/dev/null) && \
	if [ -n "$$S3_BUCKET" ]; then \
		aws s3 ls s3://$$S3_BUCKET/data/ --recursive --human-readable; \
	else \
		echo "Error: Run 'make apply' first to create resources"; \
	fi

s3-sync:
	@S3_BUCKET=$$(cd terraform && terraform output -raw s3_bucket_name 2>/dev/null) && \
	if [ -n "$$S3_BUCKET" ]; then \
		mkdir -p ./data-backup && \
		aws s3 sync s3://$$S3_BUCKET/data/ ./data-backup/ && \
		echo "Data downloaded to ./data-backup/"; \
	else \
		echo "Error: Run 'make apply' first to create resources"; \
	fi

clean:
	@echo "Stopping local Docker container..."
	@docker stop astound-lambda-test 2>/dev/null || true
	@docker rm astound-lambda-test 2>/dev/null || true
	@echo "Cleaned up local test container"

destroy:
	@echo "⚠️  WARNING: This will destroy ALL resources and DELETE all scraped data!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read -r confirmation
	cd terraform && terraform destroy

