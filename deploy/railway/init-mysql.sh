#!/bin/bash
# Idempotent MariaDB setup. Creates the datadir on first run, and ensures the
# `idm` database + `idm` user exist on every boot (so DB_PASSWORD changes apply).
set -e

DB_PASSWORD="${DB_PASSWORD:-idm-change-me}"
DATADIR="${MYSQL_DATADIR:-/var/lib/mysql}"
SOCK=/run/mysqld/mysqld.sock

mkdir -p /etc/mysql/conf.d
cat > /etc/mysql/conf.d/idm.cnf <<EOF
[mysqld]
datadir=$DATADIR
bind-address=127.0.0.1
skip-name-resolve
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
innodb_buffer_pool_size=128M
EOF

if [ ! -d "$DATADIR/mysql" ]; then
  echo "Initializing MariaDB datadir at $DATADIR..."
  mariadb-install-db --user=mysql --datadir="$DATADIR" --auth-root-authentication-method=normal --skip-test-db
fi

NEED_SHUTDOWN=0
if ! mysqladmin --protocol=socket --socket="$SOCK" ping --silent 2>/dev/null; then
  echo "Starting MariaDB temporarily for setup..."
  /usr/sbin/mariadbd --user=mysql &
  TMP_PID=$!
  for _ in $(seq 1 30); do
    mysqladmin --protocol=socket --socket="$SOCK" ping --silent 2>/dev/null && break
    sleep 1
  done
  NEED_SHUTDOWN=1
fi

mysql --protocol=socket --socket="$SOCK" -u root <<EOSQL
CREATE DATABASE IF NOT EXISTS idm;
CREATE USER IF NOT EXISTS 'idm'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER 'idm'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON idm.* TO 'idm'@'%';
FLUSH PRIVILEGES;
EOSQL

if [ "$NEED_SHUTDOWN" = "1" ]; then
  mysqladmin --protocol=socket --socket="$SOCK" -u root shutdown
  wait "$TMP_PID" 2>/dev/null || true
fi

echo "MySQL ready."
