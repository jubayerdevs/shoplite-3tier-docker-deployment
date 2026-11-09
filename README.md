# ShopLite — Local Three-Tier Docker Deployment

> **Important:** This repository is designed for a local VirtualBox simulation because the assignment owner does not currently have an AWS account. It demonstrates the application, Docker, Docker Hub, Nginx, private VM networking and database persistence. It does **not** create real AWS EC2 instances, VPCs or Security Groups. Obtain instructor approval before submitting the local simulation as an alternative.

## 1. Project overview

ShopLite is a small product catalogue with:
- Frontend: HTML, CSS and browser JavaScript served by an Nginx container.
- Backend: Node.js + Express REST API.
- Database: MySQL 8 container with a named Docker volume.
- Reverse proxy: Nginx installed directly on EC2-1's Ubuntu VM (not in a container).
- Images: frontend and backend are built on the development computer and pushed to Docker Hub. VMs only pull versioned images.

## 2. Architecture

```text
Windows browser
  |
  | http://192.168.56.10:80
  v
EC2-1 / Ubuntu / 192.168.56.10
  |-- Host Nginx (installed on OS)
  |     |-- /       -> 127.0.0.1:8080 -> frontend container
  |     `-- /api/*  -> 192.168.56.20:5000 -> backend container
  |
  v  Host-only private network
EC2-2 / Ubuntu / 192.168.56.20
  `-- Node.js API container (port 3000 internally; 5000 on VM)
        |
        v  Host-only private network, TCP 3306
EC2-3 / Ubuntu / 192.168.56.30
  `-- MySQL container
        `-- named volume: shoplite-mysql-data
```

Each VM has its own user-defined Docker network. Docker networks do not span Docker hosts; VM-to-VM communication uses the VirtualBox Host-only network.

## 3. Tools

On the Windows development computer:
- Oracle VirtualBox
- Ubuntu Server 24.04 LTS ISO
- Visual Studio Code
- Docker Desktop
- Git
- Docker Hub account
- GitHub account

On all three Ubuntu VMs:
- Docker Engine and Docker Compose plugin

Additionally on EC2-1:
- Nginx installed directly on Ubuntu

No Node.js source tree is copied to a VM. Node.js is included in the backend image.

## 4. VM sizing and networking

Suggested starting allocation (adjust to the host computer's RAM):
- 2 vCPU per VM
- 1–2 GB RAM per VM
- 20 GB virtual disk per VM

Create three Ubuntu Server VMs:
- `ShopLite-EC2-1`
- `ShopLite-EC2-2`
- `ShopLite-EC2-3`

Configure two VirtualBox adapters on each:
1. Adapter 1: NAT (outbound internet for package and image downloads).
2. Adapter 2: Host-only Adapter (private VM communication).

Create a Host-only network:
- Host IPv4: `192.168.56.1`
- Mask: `255.255.255.0`
- DHCP: disabled (or reserve addresses and still configure static VM addresses).

Private VM addresses:
| VM | Private IP |
|---|---|
| EC2-1 | 192.168.56.10/24 |
| EC2-2 | 192.168.56.20/24 |
| EC2-3 | 192.168.56.30/24 |

Find interface names with `ip -br addr`. Commonly `enp0s3` is NAT and `enp0s8` is Host-only, but verify on each VM.

Example Netplan file (adapt interface names and filename to the VM):
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.56.10/24
```
Use `.20/24` on EC2-2 and `.30/24` on EC2-3. Do not configure a default gateway on the Host-only interface. Apply with `sudo netplan try` then `sudo netplan apply`. Test with `ping -c 4 192.168.56.20` and `ping -c 4 192.168.56.30`.

## 5. Install Docker on all Ubuntu VMs

Follow Docker's official Ubuntu Engine installation instructions:
https://docs.docker.com/engine/install/ubuntu/

After installation:
```bash
sudo systemctl enable --now docker
sudo docker run hello-world
```
The scripts use `sudo docker`, so adding your user to the Docker group is optional.

Install host Nginx only on EC2-1:
```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable --now nginx
```

## 6. Build and publish images on the development computer

Edit commands below to use your Docker Hub username (not the example name).

From the repository root:
```bash
docker login
docker build -t YOUR_DOCKERHUB_USERNAME/shoplite-frontend:v1.0.0 ./frontend
docker build -t YOUR_DOCKERHUB_USERNAME/shoplite-backend:v1.0.0 ./backend
docker push YOUR_DOCKERHUB_USERNAME/shoplite-frontend:v1.0.0
docker push YOUR_DOCKERHUB_USERNAME/shoplite-backend:v1.0.0
```

Use a version tag such as `v1.0.0`; do not rely on `latest` alone. The application source is built here, never on the VMs.

Docker Hub repositories:
- `https://hub.docker.com/r/YOUR_DOCKERHUB_USERNAME/shoplite-frontend`
- `https://hub.docker.com/r/YOUR_DOCKERHUB_USERNAME/shoplite-backend`

## 7. Deploy database on EC2-3

Set secrets in the EC2-3 shell (use strong unique values):
```bash
export MYSQL_ROOT_PASSWORD='REPLACE_WITH_STRONG_ROOT_PASSWORD'
export MYSQL_PASSWORD='REPLACE_WITH_STRONG_APP_PASSWORD'
```

Copy `deployment/ec2-3/deploy-database.sh` to EC2-3 (deployment scripts/configuration are allowed; application source code is not). Then:
```bash
chmod +x deploy-database.sh
./deploy-database.sh
sudo docker ps
sudo docker volume ls
sudo docker volume inspect shoplite-mysql-data
sudo docker logs shoplite-mysql
```

The database port is bound to `192.168.56.30`, not all interfaces. MySQL data is stored in the named volume `shoplite-mysql-data`.

## 8. Deploy backend on EC2-2

Set the same application DB password:
```bash
export DB_PASSWORD='REPLACE_WITH_THE_SAME_APP_PASSWORD'
```
Copy `deployment/ec2-2/deploy-backend.sh` to EC2-2 and edit the Docker Hub username, or set it:
```bash
export DOCKERHUB_USER='YOUR_DOCKERHUB_USERNAME'
chmod +x deploy-backend.sh
./deploy-backend.sh
sudo docker ps
sudo docker logs shoplite-backend
curl http://192.168.56.20:5000/health
curl http://192.168.56.20:5000/api/products
```
Expected health response:
```json
{"status":"healthy","database":"connected"}
```

## 9. Deploy frontend and configure host Nginx on EC2-1

On EC2-1, set the Docker Hub username and run the frontend deployment script:
```bash
export DOCKERHUB_USER='YOUR_DOCKERHUB_USERNAME'
chmod +x deploy-frontend.sh
./deploy-frontend.sh
```

Copy `deployment/ec2-1/nginx.conf` to EC2-1 as `/etc/nginx/sites-available/shoplite`, then:
```bash
sudo ln -sfn /etc/nginx/sites-available/shoplite /etc/nginx/sites-enabled/shoplite
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

Open in the Windows browser:
`http://192.168.56.10`

Add a product and refresh the page. It should remain visible because it is stored in MySQL.

## 10. Security model for the local simulation

Intended traffic:
| Destination | Port | Allowed source |
|---|---:|---|
| EC2-1 | 80 | Host-only Windows host (192.168.56.1) |
| EC2-2 | 5000 | EC2-1 (192.168.56.10) |
| EC2-3 | 3306 | EC2-2 (192.168.56.20) |

The database VM has no bridged/public adapter. Its NAT adapter provides outbound package/image access; it is not an inbound public service. The MySQL published port binds only to its Host-only IP.

Run the firewall scripts from this repository on the relevant VM, supplying the actual Host-only interface name:
```bash
sudo bash backend-firewall.sh enp0s8
sudo bash database-firewall.sh enp0s8
```
The scripts use Docker's `DOCKER-USER` chain and conntrack's original destination port because Docker DNAT changes the destination port before the filter chain. Inspect:
```bash
sudo iptables -L DOCKER-USER -n -v
```
For persistence after reboot:
```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```
Test the rules before ending your management session. These are Linux firewall controls, not AWS Security Groups.

## 11. Database persistence test

1. Add a product in the browser.
2. Confirm it appears after refreshing.
3. On EC2-3 run:
   ```bash
   sudo docker volume inspect shoplite-mysql-data
   sudo docker rm -f shoplite-mysql
   ```
4. Recreate the MySQL container using the same named volume and same database credentials:
   ```bash
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
   ```
5. Wait for MySQL startup, then refresh the browser. The product should remain.
6. Reboot EC2-3 and confirm the container starts and the product remains.

Never run `docker volume rm shoplite-mysql-data` during this test.

## 12. Rollback

Keep previous versioned images in Docker Hub. To roll back the backend, change the image tag in the deployment command/script to the previous known-good tag, pull it, remove the failed container and recreate it with the same environment variables, network and port mapping. Verify `/health` and `/api/products`.

## 13. Troubleshooting

- Website does not open: check `sudo systemctl status nginx`, `sudo nginx -t`, `sudo docker ps` on EC2-1.
- API returns 502: from EC2-1 run `curl http://192.168.56.20:5000/health`; check backend logs on EC2-2 and Nginx error log with `sudo tail -n 50 /var/log/nginx/error.log`.
- Backend cannot connect to DB: check MySQL logs, database credentials, private IP and firewall rules.
- Products disappear: confirm the container uses `-v shoplite-mysql-data:/var/lib/mysql`; do not remove the volume.
- VM cannot reach another VM: check VirtualBox Host-only adapter, static IP, interface name and subnet mask.

Useful commands:
```bash
ip -br addr
sudo docker ps -a
sudo docker logs shoplite-backend
sudo docker network ls
sudo docker network inspect shoplite-backend-net
sudo docker volume ls
sudo docker volume inspect shoplite-mysql-data
sudo iptables -L DOCKER-USER -n -v
```

## 14. Part E — scenario answers

### Q1. Browser shows 502 Bad Gateway for API calls

I would first check the host Nginx service and configuration using `sudo systemctl status nginx` and `sudo nginx -t`. Then I would test the backend directly from EC2-1 using `curl http://192.168.56.20:5000/health`. If that fails, I would inspect `docker ps` and `docker logs shoplite-backend` on EC2-2. I would also verify that EC2-2 can reach MySQL on EC2-3 and check the backend environment variables, private IP addresses and firewall rules. After fixing the failing layer, I would test the health endpoint and product API again.

### Q2. How can OS security patches reach EC2-3 without breaking the database security rule?

The database VM can use its NAT adapter for outbound package downloads. I can run `sudo apt update` and `sudo apt upgrade` from the VM. The NAT adapter is used for outbound internet access; MySQL remains bound to the private interface and inbound port 3306 remains restricted to the backend VM. In AWS, the equivalent design would use a private subnet with controlled outbound access through a NAT Gateway or another approved patching method.

### Q3. How can I roll back a faulty backend release within two minutes?

I would keep versioned backend images in Docker Hub, for example `v1.0.0` and `v1.1.0`. If `v1.1.0` fails, I would pull the previously tested `v1.0.0`, remove the faulty backend container and recreate it using the previous image with the same environment variables, network and port mapping. I would then verify the health endpoint and test adding a product. The database volume is not changed during a backend rollback.

### Q4. What is the impact of opening database port 3306 to 0.0.0.0/0?

It permits connection attempts from any IPv4 source that can reach the server. This increases the risk of password attacks, unauthorized access and data exposure. The database should have no public IP, and its port should be reachable only from the backend's private IP. I would use least-privilege firewall rules, strong credentials, restricted database permissions and regular firewall audits. In AWS, a database Security Group should reference the backend Security Group as its source rather than allow the whole internet.

### Q5. Which tier may fail first if traffic grows ten times?

The backend may become the first bottleneck because it handles API requests and database operations, although the actual bottleneck depends on resource usage and query patterns. I would monitor CPU, memory, response time and database connections to identify the first constrained resource. I would then run multiple backend instances behind a load balancer, increase capacity, optimize SQL queries and indexes, and add caching for frequently requested catalogue data. In a real AWS deployment, I would consider an Application Load Balancer and EC2 Auto Scaling.

## 15. Screenshots and evidence

See `screenshots/README.md`. The included images are illustrative previews only; they are **not** proof of a live deployment. Replace them with your own screenshots after running the project:
- Running application in browser
- Product added and visible after refresh
- `docker ps` on each VM
- `docker network ls` and `docker network inspect` on each VM
- `docker volume ls` and `docker volume inspect` on EC2-3
- Inbound firewall rules on all VMs
- EC2-3/VirtualBox network settings showing no bridged adapter
- Product persistence after database container removal/recreation

## 16. Cleanup

After evaluation, stop the VMs and remove them from VirtualBox if no longer needed. Remove local Docker containers/images/volumes only when you no longer need the project data. Remember that deleting the MySQL named volume permanently deletes the local database data.

## 17. References

- Docker Engine on Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Docker networking: https://docs.docker.com/engine/network/
- Docker volumes: https://docs.docker.com/engine/storage/volumes/
- Docker packet filtering/firewalls: https://docs.docker.com/engine/network/packet-filtering-firewalls/
- Ubuntu Server Netplan: https://ubuntu.com/server/docs/network-configuration
