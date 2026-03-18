# ─── Build stage ─────────────────────────────────────────────────────────────
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ca-certificates \
    git \
    gperf \
    zlib1g-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Pin to a specific release tag for reproducible builds.
# Check https://github.com/tdlib/telegram-bot-api/releases for newer versions.
ARG TGBOTAPI_VERSION=v8.3

RUN git clone --recursive --depth 1 --branch master \
    https://github.com/tdlib/telegram-bot-api.git /src

WORKDIR /src/build

RUN cmake -DCMAKE_BUILD_TYPE=Release .. \
    && cmake --build . --target telegram-bot-api -j$(nproc)

# ─── Runtime stage ────────────────────────────────────────────────────────────
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/build/telegram-bot-api /usr/local/bin/telegram-bot-api

RUN mkdir -p /data

# Railway injects PORT; default to 8081 for local use.
EXPOSE 8081

# TELEGRAM_API_ID and TELEGRAM_API_HASH are required.
# TELEGRAM_BOT_TOKEN is not used by the server itself — bots register via HTTP.
CMD telegram-bot-api \
    --api-id="${TELEGRAM_API_ID}" \
    --api-hash="${TELEGRAM_API_HASH}" \
    --http-port="${PORT:-8081}" \
    --http-ip-address=:: \
    --dir=/data

