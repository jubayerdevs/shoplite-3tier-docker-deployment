#!/usr/bin/env bash
# Run on EC2-3 after confirming the private interface name.
# Docker DNAT changes the destination to the container, so conntrack's
# original destination port is used to match published host port 3306.
set -euo pipefail
PRIVATE_IF="${1:?Usage: sudo bash database-firewall.sh <private-interface>}"

sudo iptables -C DOCKER-USER -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 3306 -s 192.168.56.20 -j ACCEPT 2>/dev/null || \
sudo iptables -I DOCKER-USER 1 -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 3306 -s 192.168.56.20 -j ACCEPT

sudo iptables -C DOCKER-USER -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 3306 -j DROP 2>/dev/null || \
sudo iptables -I DOCKER-USER 2 -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 3306 -j DROP

echo "MySQL port 3306 is restricted to EC2-2 on the private interface."
