#!/usr/bin/env bash
set -euo pipefail

# Change this to your Docker Hub username.
DOCKERHUB_USER="${DOCKERHUB_USER:-YOUR_DOCKERHUB_USERNAME}"
IMAGE="${DOCKERHUB_USER}/shoplite-backend:v1.0.0"

# Set these before running the script, or replace the example values.
: "${DB_PASSWORD:?Set DB_PASSWORD before running this script}"

sudo docker network inspect shoplite-backend-net >/dev/null 2>&1 || \
  sudo docker network create shoplite-backend-net

sudo docker pull "$IMAGE"
sudo docker rm -f shoplite-backend >/dev/null 2>&1 || true

sudo docker run -d \
  --name shoplite-backend \
  --network shoplite-backend-net \
  -p 192.168.56.20:5000:3000 \
  --restart unless-stopped \
  -e PORT=3000 \
  -e DB_HOST=192.168.56.30 \
  -e DB_PORT=3306 \
  -e DB_NAME=shoplite \
  -e DB_USER=shopliteuser \
  -e DB_PASSWORD="$DB_PASSWORD" \
  "$IMAGE"

echo "Backend container deployed: $IMAGE"
