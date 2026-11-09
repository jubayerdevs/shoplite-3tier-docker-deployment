#!/usr/bin/env bash
set -euo pipefail

# Change this to your Docker Hub username.
DOCKERHUB_USER="${DOCKERHUB_USER:-YOUR_DOCKERHUB_USERNAME}"
IMAGE="${DOCKERHUB_USER}/shoplite-frontend:v1.0.0"

sudo docker network inspect shoplite-frontend-net >/dev/null 2>&1 || \
  sudo docker network create shoplite-frontend-net

sudo docker pull "$IMAGE"
sudo docker rm -f shoplite-frontend >/dev/null 2>&1 || true

sudo docker run -d \
  --name shoplite-frontend \
  --network shoplite-frontend-net \
  -p 127.0.0.1:8080:80 \
  --restart unless-stopped \
  "$IMAGE"

echo "Frontend container deployed: $IMAGE"
