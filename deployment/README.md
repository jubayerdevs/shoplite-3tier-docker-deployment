# Deployment notes

Run application builds on the development computer only. EC2-like VMs must only pull prebuilt images from Docker Hub.

## VM addressing

| VM | Host-only/private IP | Role |
|---|---|---|
| EC2-1 | 192.168.56.10 | Host Nginx + frontend container |
| EC2-2 | 192.168.56.20 | Backend container |
| EC2-3 | 192.168.56.30 | MySQL container + named volume |

Each VM uses a NAT adapter for outbound package/image downloads and a Host-only adapter for private VM-to-VM communication. Do not configure a default gateway on the Host-only adapter.

## Network creation

Create a separate user-defined Docker network on each VM:
- EC2-1: `shoplite-frontend-net`
- EC2-2: `shoplite-backend-net`
- EC2-3: `shoplite-database-net`

These Docker networks are local to their respective Docker hosts. Cross-VM traffic uses the VirtualBox Host-only network and the VMs' private IP addresses.

## Deployment order

1. EC2-3: run `deploy-database.sh`.
2. EC2-2: export `DB_PASSWORD` and run `deploy-backend.sh`.
3. EC2-1: run `deploy-frontend.sh`.
4. EC2-1: copy `nginx.conf` to `/etc/nginx/sites-available/shoplite`, enable it and reload Nginx.

## Firewall scripts

Find the private interface name with `ip -br addr` (often `enp0s8`). Run the backend/database firewall scripts with that interface name. Inspect rules using `sudo iptables -L DOCKER-USER -n -v`.

For persistence of iptables rules across reboot, install `iptables-persistent` and save rules with `sudo netfilter-persistent save`. Test carefully before closing your SSH session.

## Security notes

- Do not expose MySQL to a public or bridged interface.
- Bind MySQL's published port to `192.168.56.30`, not `0.0.0.0`.
- Restrict port 3306 to EC2-2's private IP using the Docker `DOCKER-USER` chain.
- Restrict backend port 5000 to EC2-1's private IP.
- Use unique strong passwords and do not commit them to Git.
- Docker-published ports can bypass simple UFW rules; account for Docker's packet-filtering behavior.
- These are local firewall/network controls, not AWS Security Groups.
