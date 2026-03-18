.PHONY: build docker-build run run-bot-api run-file-server

IMAGE ?= voxito-telegram-bot-api
DATA_DIR ?= $(HOME)/code/personal/telegram-bot-api/build/data

build:
	go build -o telegram-file-server ./cmd/telegram-file-server

docker-build:
	docker build -t $(IMAGE) .

# Run both services inside Docker (mirrors production).
# Requires: TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_FILE_SERVER_TOKEN
run: docker-build
	docker run --rm \
		-p 8081:8081 \
		-p 8082:8082 \
		-v $(DATA_DIR):/data \
		-e TELEGRAM_API_ID=$(TELEGRAM_API_ID) \
		-e TELEGRAM_API_HASH=$(TELEGRAM_API_HASH) \
		-e TELEGRAM_FILE_SERVER_TOKEN=$(TELEGRAM_FILE_SERVER_TOKEN) \
		$(IMAGE)

# Run only telegram-bot-api inside Docker.
# Requires: TELEGRAM_API_ID, TELEGRAM_API_HASH
run-bot-api: docker-build
	docker run --rm \
		-p 8081:8081 \
		-v $(DATA_DIR):/data \
		-e TELEGRAM_API_ID=$(TELEGRAM_API_ID) \
		-e TELEGRAM_API_HASH=$(TELEGRAM_API_HASH) \
		--entrypoint telegram-bot-api \
		$(IMAGE) \
		--api-id="$(TELEGRAM_API_ID)" \
		--api-hash="$(TELEGRAM_API_HASH)" \
		--http-port=8081 \
		--http-ip-address=:: \
		--dir=/data \
		--local \
		--verbosity=1

# Run only telegram-file-server locally via go run.
# Requires: TELEGRAM_FILE_SERVER_TOKEN
run-file-server:
	TELEGRAM_FILE_SERVER_TOKEN=$(TELEGRAM_FILE_SERVER_TOKEN) \
	TELEGRAM_FILE_SERVER_ROOT=$(DATA_DIR) \
	TELEGRAM_FILE_SERVER_PORT=$(TELEGRAM_FILE_SERVER_PORT) \
	go run ./cmd/telegram-file-server
