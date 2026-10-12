#!/bin/bash
# Idempotent Kafka KRaft storage setup. Formats the log dirs on first run only.
set -e

export JAVA_HOME=/usr/lib/jvm/default-java
KAFKA_LOG_DIRS="${KAFKA_LOG_DIRS:-/data/kafka}"

mkdir -p "$KAFKA_LOG_DIRS"
# Point the broker config at the (possibly volume-backed) log dirs.
sed -i "s|^log.dirs=.*|log.dirs=$KAFKA_LOG_DIRS|" /etc/kafka/server.properties

if [ ! -f "$KAFKA_LOG_DIRS/meta.properties" ]; then
  echo "Formatting Kafka KRaft storage..."
  CLUSTER_ID=$(/opt/kafka/bin/kafka-storage.sh random-uuid)
  /opt/kafka/bin/kafka-storage.sh format --standalone -t "$CLUSTER_ID" -c /etc/kafka/server.properties
fi

echo "Kafka storage ready."
