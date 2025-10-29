# Use AWS Lambda Node.js 20 base image
FROM public.ecr.aws/lambda/nodejs:20

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Install Chromium and dependencies required by Playwright
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

# Copy package files from fastplay submodule
COPY fastplay/package.json fastplay/pnpm-lock.yaml ./

# Install pnpm and dependencies
RUN npm install -g pnpm@10.12.1 && \
    pnpm install --prod --frozen-lockfile

# Install Playwright browsers and dependencies
RUN npx playwright install chromium && \
    npx playwright install-deps chromium

# Copy application code from fastplay submodule
COPY fastplay/src ./src
COPY fastplay/playwright.config.ts ./
COPY lambda ./lambda

# Set the handler
CMD [ "lambda/index.handler" ]

