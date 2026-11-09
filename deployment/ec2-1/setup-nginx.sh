#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y nginx

sudo install -m 0644 nginx.conf /etc/nginx/sites-available/shoplite
sudo ln -sfn /etc/nginx/sites-available/shoplite /etc/nginx/sites-enabled/shoplite
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

echo "Host-level Nginx configured."
