#!/bin/bash
# Container entrypoint: initialize persistent state, then hand over to supervisord
# which runs MariaDB + Kafka + the IDM app.
set -e

DATA_DIR="${DATA_DIR:-/data}"
export MYSQL_DATADIR="$DATA_DIR/mysql"
export KAFKA_LOG_DIRS="$DATA_DIR/kafka"

mkdir -p "$MYSQL_DATADIR" "$KAFKA_LOG_DIRS" "$DATA_DIR/downloads"
chown -R mysql:mysql "$MYSQL_DATADIR"

/app/init-mysql.sh
/app/init-kafka.sh

echo "Starting supervisord (mariadb + kafka + idm)..."
exec /usr/bin/supervisord -c /app/supervisord.conf
