# Pin Node.js to 22.23.4-slim (21 Oct 2026 security release): Brotli decoder
# RCE (CVE-2026-111497), TLS hostname bypasses, and eMudhra CA removal.
# The digest is the multi-arch index for node:22.23.4-slim. Keep both FROM
# lines identical.
# To bump, print the new index digest and update the tag and digest together:
#   docker buildx imagetools inspect node:<version>-slim
# Stage 1: Build frontend and backend
FROM node:22.23.4-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d AS build

WORKDIR /app

# Copy workspace package files for dependency caching
COPY package.json package-lock.json ./
COPY frontend/package.json frontend/
COPY backend/package.json backend/

RUN npm ci

# Copy source and build both workspaces
COPY frontend/ frontend/
COPY backend/ backend/

RUN npm run build


# Stage 2: Production image with system Chromium.
# Same Node pin as the build stage.
FROM node:22.23.4-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d

# Chromium stays on apt and unpinned so a rebuild installs Debian's current
# package, which is how Chrome 156 critical fixes (and later updates) land.
# Install Chromium and dependencies for Puppeteer
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    fonts-liberation \
    libgbm1 \
    libnss3 \
    libatk-bridge2.0-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libcups2 \
    libdrm2 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

WORKDIR /app

# Copy package files and install production deps only
COPY package.json package-lock.json ./
COPY backend/package.json backend/

RUN npm ci --omit=dev --workspace=backend

# Copy built artifacts
COPY --from=build /app/frontend/dist frontend/dist
COPY --from=build /app/backend/dist backend/dist

# Data directory for SQLite + evidence screenshots
RUN mkdir -p /app/data

EXPOSE 3001

CMD ["node", "backend/dist/index.js"]
