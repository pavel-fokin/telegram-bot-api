# ─── Build stage (telegram-bot-api C++ binary) ───────────────────────────────
FROM ubuntu:24.04 AS tgbotapi-builder

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

# ─── Build stage (telegram-file-server Go binary) ────────────────────────────
FROM golang:1.24-bookworm AS fileserver-builder

WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY cmd/ ./cmd/

RUN CGO_ENABLED=0 GOOS=linux go build -o /telegram-file-server ./cmd/telegram-file-server

# ─── Runtime stage ────────────────────────────────────────────────────────────
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=tgbotapi-builder /src/build/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY --from=fileserver-builder /telegram-file-server /usr/local/bin/telegram-file-server
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && mkdir -p /data

# telegram-bot-api: 8081 (Railway injects PORT; default 8081 for local use)
# telegram-file-server: 8082
EXPOSE 8081
EXPOSE 8082

# TELEGRAM_API_ID and TELEGRAM_API_HASH are required for telegram-bot-api.
# TELEGRAM_FILE_SERVER_TOKEN is required for telegram-file-server.
CMD ["docker-entrypoint.sh"]
