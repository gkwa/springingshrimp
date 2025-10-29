#!/bin/bash

set -e

echo "🧪 Local Lambda Testing Script"
echo "=============================="

# Initialize fastplay submodule if not already done
if [ ! -f "../fastplay/package.json" ]; then
    echo "📦 Initializing fastplay submodule..."
    cd ..
    git submodule update --init --recursive
    cd terraform
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Build the Docker image from parent directory (springingshrimp root)
echo ""
echo "1️⃣  Building Docker image..."
cd ..
docker build --platform linux/amd64 -f lambda/Dockerfile -t astound-lambda-test .
cd terraform

# Check if container is already running
if [ "$(docker ps -q -f name=astound-lambda-test)" ]; then
    echo "   Stopping existing container..."
    docker stop astound-lambda-test
    docker rm astound-lambda-test
fi

# Run the container with Lambda Runtime Interface Emulator
echo ""
echo "2️⃣  Starting Lambda container locally..."
echo "   Port: 9000"
echo ""

docker run -d \
    --name astound-lambda-test \
    -p 9000:8080 \
    -e AWS_ACCESS_KEY_ID=test \
    -e AWS_SECRET_ACCESS_KEY=test \
    -e AWS_REGION=us-east-1 \
    -e SECRET_ARN=arn:aws:secretsmanager:us-east-1:123456789012:secret:test \
    -e S3_BUCKET=test-bucket \
    -e ASTOUND_CONFIG=test \
    astound-lambda-test

# Wait for container to be ready
echo "   Waiting for container to be ready..."
sleep 5

# Test the function
echo ""
echo "3️⃣  Testing Lambda function..."
echo ""

response=$(curl -s -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
    -d '{"dryRun": false}')

echo "Response:"
echo "$response" | jq

# Show logs
echo ""
echo "4️⃣  Container logs:"
echo ""
docker logs astound-lambda-test

# Cleanup prompt
echo ""
echo "✅ Test complete!"
echo ""
echo "Container is still running. To view logs:"
echo "   docker logs -f astound-lambda-test"
echo ""
echo "To stop and remove the container:"
echo "   docker stop astound-lambda-test && docker rm astound-lambda-test"
echo ""

