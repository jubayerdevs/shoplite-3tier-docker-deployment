#!/usr/bin/env bash
# Run on EC2-2 after confirming the private interface name.
# Docker DNAT changes the destination port to 3000 inside the container,
# so --ctorigdstport matches the original published host port 5000.
set -euo pipefail
PRIVATE_IF="${1:?Usage: sudo bash backend-firewall.sh <private-interface>}"

sudo iptables -C DOCKER-USER -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 5000 -s 192.168.56.10 -j ACCEPT 2>/dev/null || \
sudo iptables -I DOCKER-USER 1 -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 5000 -s 192.168.56.10 -j ACCEPT

sudo iptables -C DOCKER-USER -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 5000 -j DROP 2>/dev/null || \
sudo iptables -I DOCKER-USER 2 -i "$PRIVATE_IF" -p tcp \
  --ctorigdstport 5000 -j DROP

echo "Backend port 5000 is restricted to EC2-1 on the private interface."
