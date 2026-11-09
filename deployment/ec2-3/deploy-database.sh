#!/usr/bin/env bash
set -euo pipefail

# Set these before running this script.
: "${MYSQL_ROOT_PASSWORD:?Set MYSQL_ROOT_PASSWORD before running this script}"
: "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD before running this script}"

sudo docker network inspect shoplite-database-net >/dev/null 2>&1 || \
  sudo docker network create shoplite-database-net

sudo docker volume inspect shoplite-mysql-data >/dev/null 2>&1 || \
  sudo docker volume create shoplite-mysql-data

sudo docker pull mysql:8.0
sudo docker rm -f shoplite-mysql >/dev/null 2>&1 || true

sudo docker run -d \
  --name shoplite-mysql \
  --network shoplite-database-net \
  -p 192.168.56.30:3306:3306 \
  --restart unless-stopped \
  -v shoplite-mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  -e MYSQL_DATABASE=shoplite \
  -e MYSQL_USER=shopliteuser \
  -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
  mysql:8.0

echo "MySQL container deployed with persistent named volume."
