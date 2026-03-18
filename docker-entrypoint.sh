#!/bin/sh
set -e

telegram-file-server &
FILE_SERVER_PID=$!

trap 'kill $FILE_SERVER_PID 2>/dev/null; exit' INT TERM

telegram-bot-api \
    --api-id="${TELEGRAM_API_ID}" \
    --api-hash="${TELEGRAM_API_HASH}" \
    --http-port="${PORT:-8081}" \
    --http-ip-address=:: \
    --dir=/data \
    --local \
    --verbosity=1

kill $FILE_SERVER_PID 2>/dev/null
