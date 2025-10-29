#!/bin/bash

# Debug script to check TypeScript installation in Docker
set -e

echo "🔍 Building Docker image up to pnpm install step..."
docker build --platform linux/amd64 -f lambda/Dockerfile --target debug . -t lambda-debug 2>/dev/null || true

echo ""
echo "🐚 Starting interactive shell in container..."
echo "Run these commands to debug:"
echo ""
echo "  pwd"
echo "  ls -la"
echo "  ls -la node_modules/.bin/ | grep tsc"
echo "  file node_modules/.bin/tsc"
echo "  cat node_modules/.bin/tsc"
echo "  which tsc"
echo "  node_modules/.bin/tsc --version"
echo "  ./node_modules/.bin/tsc --version"
echo ""

docker run --rm -it --platform linux/amd64 \
  --entrypoint /bin/bash \
  lambda-debug || \
docker run --rm -it --platform linux/amd64 \
  -w /var/task \
  -v "$(pwd)/fastplay:/fastplay:ro" \
  -v "$(pwd)/lambda:/lambda:ro" \
  --entrypoint /bin/bash \
  public.ecr.aws/lambda/nodejs:20 \
  -c "
    set -e
    echo '📦 Installing pnpm...'
    npm install -g pnpm@10.12.1 >/dev/null 2>&1
    
    echo '📋 Copying package files...'
    cp /fastplay/package.json /fastplay/pnpm-lock.yaml .
    
    echo '⬇️  Installing dependencies...'
    pnpm install --frozen-lockfile
    
    echo ''
    echo '🔍 Debug Info:'
    echo '=============='
    echo 'Current directory:'
    pwd
    echo ''
    echo 'node_modules/.bin/tsc exists?'
    ls -la node_modules/.bin/tsc || echo 'NOT FOUND'
    echo ''
    echo 'File type:'
    file node_modules/.bin/tsc || echo 'N/A'
    echo ''
    echo 'First few lines:'
    head -5 node_modules/.bin/tsc || echo 'N/A'
    echo ''
    echo 'TypeScript version test:'
    node_modules/.bin/tsc --version || echo 'FAILED'
    echo ''
    echo '🐚 Starting shell for manual testing...'
    /bin/bash
  "

