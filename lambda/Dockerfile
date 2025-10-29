# Use AWS Lambda Node.js 20 base image
FROM public.ecr.aws/lambda/nodejs:20

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Install system dependencies FIRST (rarely changes)
# hadolint ignore=DL3041
RUN dnf install -y \
    atk \
    cups-libs \
    gtk3 \
    libXcomposite \
    alsa-lib \
    libXcursor \
    libXdamage \
    libXext \
    libXi \
    libXrandr \
    libXScrnSaver \
    libXtst \
    pango \
    at-spi2-atk \
    libXt \
    xorg-x11-server-Xvfb \
    xorg-x11-xauth \
    dbus-glib \
    dbus-glib-devel \
    nss \
    mesa-libgbm \
    && dnf clean all

# Copy package files from BOTH fastplay and lambda
COPY fastplay/package.json fastplay/pnpm-lock.yaml ./
COPY lambda/package.json ./lambda-package.json

# Install pnpm globally (rarely changes)
RUN npm install -g pnpm@10.12.1

# Install dependencies from fastplay
RUN pnpm install --frozen-lockfile

# Install additional dependencies from lambda (AWS SDK + TypeScript)
RUN pnpm add @aws-sdk/client-s3@^3.709.0 @aws-sdk/client-ssm@^3.709.0 \
    --save-dev typescript@^5.7.2 @types/aws-lambda@^8.10.145

# Set Playwright browsers path to a shared location
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# Install Playwright browsers to shared location
RUN npx playwright install chromium && \
    chmod -R 755 /opt/ms-playwright

# Copy application code LAST (changes most frequently)
COPY fastplay/src ./src
COPY fastplay/playwright.config.ts ./
COPY lambda ./lambda

# Compile TypeScript to JavaScript - use rootDir and outDir to control structure
RUN node_modules/.bin/tsc \
    --rootDir . \
    --outDir . \
    lambda/index.ts \
    lambda/S3FileManager.ts \
    --module commonjs \
    --target ES2020 \
    --esModuleInterop \
    --skipLibCheck \
    --resolveJsonModule \
    --moduleResolution node

# Remove TypeScript source files (optional, keeps image smaller)
RUN rm -f lambda/*.ts

# Set the handler
CMD [ "lambda/index.handler" ]
