#!/bin/bash
# Starts the IDM app under supervisord: waits for MariaDB + Kafka, renders the
# YAML config, pre-creates the Kafka topic, then execs the server.
set -e

PORT="${PORT:-8081}"
DB_PASSWORD="${DB_PASSWORD:-idm-change-me}"
DATA_DIR="${DATA_DIR:-/data}"
DOWNLOAD_DIR="$DATA_DIR/downloads"

echo "Waiting for MariaDB..."
for _ in $(seq 1 60); do
  if mysqladmin -h 127.0.0.1 -u idm -p"$DB_PASSWORD" ping --silent 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "Waiting for Kafka..."
for _ in $(seq 1 60); do
  if (exec 3<>/dev/tcp/127.0.0.1/9092) 2>/dev/null; then
    break
  fi
  sleep 1
done

mkdir -p "$DOWNLOAD_DIR"

cat > /app/config.yaml <<EOF
auth:
  hash:
    cost: 10 # NOTE: currently ignored by the app (bcrypt default 10 is used)
  token:
    duration: 86400 # in seconds
    rs512_key_pair_bit_size: 2048
database:
  type: "mysql"
  host: "127.0.0.1"
  port: 3306
  username: "idm"
  password: "${DB_PASSWORD}"
  database: "idm"
log:
  level: "info"
cache:
  type: "in_memory"
  addr: ""
  username: ""
  password: ""
  db: 0
grpc:
  address: "127.0.0.1:8080"
  get_download_task_file:
    response_buffer_size: 64kb
http:
  address: "0.0.0.0:${PORT}"
  mode: "production"
mq:
  addresses: ["127.0.0.1:9092"]
  client_id: "1"
cron:
  execute_all_pending_download_task:
    schedule: "@every 1m"
    concurrency_limit: 8
  update_failed_download_task_status_to_pending:
    schedule: "@every 10m"
download:
  mode: "local"
  download_directory: "${DOWNLOAD_DIR}/"
  bucket: "idm"
  address: ""
  username: ""
  password: ""
EOF

# Make sure the Kafka topic exists so downloads start in real time
# (never fails the boot; the 1-minute cron is the fallback).
KAFKA_BROKERS="127.0.0.1:9092" /app/topic-init || true

exec /app/idm standalone-server --config-file-path /app/config.yaml
