# All-in-one image: MariaDB + Kafka (KRaft) + the IDM app in a single container,
# managed by supervisord. One Railway service, one volume (/data), no other
# infrastructure needed.

# ---------- Stage 1: build the web UI ----------
FROM node:20-alpine AS web-builder
WORKDIR /app/web
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web/ ./
RUN npm run build

# ---------- Stage 2: build the Go backend (+ topic helper) ----------
FROM golang:1.22-alpine AS go-builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
# The Go backend embeds the UI via //go:embed web/dist
COPY --from=web-builder /app/web/dist ./web/dist
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "-s -w" -o /idm ./cmd/idm/*.go \
 && CGO_ENABLED=0 GOOS=linux go build -ldflags "-s -w" -o /topic-init ./deploy/railway/topicinit/main.go

# ---------- Stage 3: fetch Kafka ----------
FROM debian:bookworm-slim AS kafka-fetch
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && curl -sL -o /tmp/kafka.tgz https://archive.apache.org/dist/kafka/3.9.0/kafka_2.13-3.9.0.tgz \
 && mkdir -p /opt/kafka \
 && tar xzf /tmp/kafka.tgz -C /opt/kafka --strip-components=1 \
 && rm /tmp/kafka.tgz \
 && rm -rf /var/lib/apt/lists/*

# ---------- Stage 4: runtime ----------
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-server mariadb-client \
        default-jre-headless \
        supervisor \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/supervisor /var/run/mysqld /data \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld

COPY --from=kafka-fetch /opt/kafka /opt/kafka
COPY --from=go-builder /idm /app/idm
COPY --from=go-builder /topic-init /app/topic-init
COPY deploy/railway/supervisord.conf /app/supervisord.conf
COPY deploy/railway/entrypoint.sh /app/entrypoint.sh
COPY deploy/railway/init-mysql.sh /app/init-mysql.sh
COPY deploy/railway/init-kafka.sh /app/init-kafka.sh
COPY deploy/railway/start-idm.sh /app/start-idm.sh
COPY deploy/railway/kafka-server.properties /etc/kafka/server.properties
RUN chmod +x /app/*.sh

EXPOSE 8081
VOLUME ["/data"]
ENTRYPOINT ["/app/entrypoint.sh"]
