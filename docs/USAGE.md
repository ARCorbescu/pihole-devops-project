# Usage Guide

How to use your deployed Pi-hole system, manage services, and utilize the monitoring tools.

---

## Table of Contents
1. [Accessing Pi-hole](#accessing-pi-hole)
2. [Using Pi-hole](#using-pihole)
3. [Monitoring Tools](#monitoring-tools)
4. [Dynamic IP Updater](#dynamic-ip-updater)
5. [Maintenance Tasks](#maintenance-tasks)
6. [Troubleshooting](#troubleshooting)

---

## Accessing Pi-hole

### Web Interface

**URL:** `http://<EC2_PUBLIC_IP>/admin`

**Login:**
- Password: The password you set in `ansible/vault.yml`

**Get your EC2 IP:**
```bash
# From terraform directory
terraform output -json | jq -r '.instance_public_ip.value'

# Or from AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=PiHole - AWS" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].PublicIpAddress" \
  --output text
```

### SSH Access

```bash
# From project root
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP>
```

**Useful SSH commands:**
```bash
# Check Docker containers
docker ps

# View Pi-hole logs
docker logs pihole

# View all container logs
docker compose -f ~/pihole-devops-project/docker/docker-compose.yml logs -f

# Restart Pi-hole
docker restart pihole
```

---

## Using Pi-hole

### Configure Your Devices

#### Option 1: Router-Level (Recommended)
Configure your router's DHCP settings to use Pi-hole as the DNS server:
1. Log into your router's admin panel
2. Find DHCP/DNS settings
3. Set Primary DNS to: `<EC2_PUBLIC_IP>`
4. Set Secondary DNS to: `1.1.1.1` (fallback)
5. Save and reboot router

**Pros:**
- All devices on your network use Pi-hole automatically
- No per-device configuration needed

**Cons:**
- Only works on your home network
- Requires router admin access

#### Option 2: Per-Device Configuration

**Windows:**
1. Control Panel → Network and Sharing Center
2. Change adapter settings → Right-click adapter → Properties
3. Select "Internet Protocol Version 4 (TCP/IPv4)" → Properties
4. Use the following DNS server addresses:
   - Preferred: `<EC2_PUBLIC_IP>`
   - Alternate: `1.1.1.1`

**macOS:**
1. System Preferences → Network
2. Select your connection → Advanced → DNS
3. Add DNS Server: `<EC2_PUBLIC_IP>`

**Linux:**
```bash
# Edit /etc/resolv.conf
sudo nano /etc/resolv.conf

# Add:
nameserver <EC2_PUBLIC_IP>
nameserver 1.1.1.1
```

**iOS/Android:**
1. WiFi Settings → Configure DNS
2. Manual → Add Server: `<EC2_PUBLIC_IP>`

### Test DNS Resolution

```bash
# Test from your local machine
dig @<EC2_PUBLIC_IP> google.com +short

# Test ad blocking
dig @<EC2_PUBLIC_IP> ads.google.com +short
# Should return 0.0.0.0 (blocked)

# Test from the Pi-hole server itself
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "dig @127.0.0.1 google.com +short"
```

### Pi-hole Web Interface Features

#### Dashboard
- **Queries Blocked**: Real-time ad blocking statistics
- **Queries Today**: Total DNS queries processed
- **Blocklist**: Number of domains on blocklist
- **Clients**: Active devices using Pi-hole

#### Query Log
- View all DNS queries in real-time
- Filter by client, domain, or status
- Whitelist/blacklist domains directly

#### Whitelist/Blacklist
```bash
# Add to whitelist (via SSH)
docker exec pihole pihole -w example.com

# Add to blacklist
docker exec pihole pihole -b ads.example.com

# View lists
docker exec pihole pihole -l
```

#### Group Management
- Create device groups (e.g., "Kids Devices", "Work Laptops")
- Apply different blocklists per group
- Schedule blocking times

---

## Monitoring Tools

### 1. Python Monitor (Webhook API)

**Endpoint:** `http://<EC2_PUBLIC_IP>:5005/stats`

**Example Request:**
```bash
curl http://<EC2_PUBLIC_IP>:5005/stats | jq
```

**Response:**
```json
{
  "domains_being_blocked": 123456,
  "dns_queries_today": 5432,
  "ads_blocked_today": 987,
  "ads_percentage_today": 18.2,
  "unique_domains": 234,
  "queries_forwarded": 3456,
  "queries_cached": 1976,
  "clients_ever_seen": 12,
  "unique_clients": 8,
  "status": "enabled"
}
```

**Use Cases:**
- Integrate with monitoring dashboards (Grafana, Prometheus)
- Create custom alerts
- Build mobile apps
- Automate reporting

**Example: Daily Stats Email**
```bash
#!/bin/bash
STATS=$(curl -s http://<EC2_PUBLIC_IP>:5005/stats)
echo "Pi-hole Daily Report: $STATS" | mail -s "Pi-hole Stats" your@email.com
```

### 2. Bash Monitor (System Resources)

**View Logs:**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker logs bash-monitor"
```

**Metrics Collected:**
- CPU usage (%)
- Memory usage (MB)
- Disk usage (GB)
- Docker container status

**Output Example:**
```
[2025-12-12 14:30:00] CPU: 12% | RAM: 456MB/1024MB | Disk: 2.1GB/8GB
[2025-12-12 14:30:00] Containers: pihole=UP python-monitor=UP bash-monitor=UP
```

---

## Dynamic IP Updater

### What It Does
Automatically updates AWS Security Group rules when your public IP changes.

### Setup

**1. Install Dependencies:**
```bash
pip3 install boto3  # Optional, script uses AWS CLI
```

**2. Configure AWS CLI:**
```bash
aws configure
# Enter your AWS credentials
```

**3. Run the Script:**

**Manual (one-time):**
```bash
python3 scripts/update_ip.py
```

**Background (continuous):**
```bash
# Run in background with nohup
nohup python3 scripts/update_ip.py > /tmp/ip_updater.log 2>&1 &

# Or use screen/tmux
screen -S ip-updater
python3 scripts/update_ip.py
# Press Ctrl+A, then D to detach
```

**As a systemd service (recommended):**
```bash
# Create service file
sudo nano /etc/systemd/system/pihole-ip-updater.service
```

```ini
[Unit]
Description=Pi-hole IP Updater
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/path/to/pihole-devops-project
ExecStart=/usr/bin/python3 /path/to/pihole-devops-project/scripts/update_ip.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start
sudo systemctl enable pihole-ip-updater
sudo systemctl start pihole-ip-updater

# Check status
sudo systemctl status pihole-ip-updater
```

### How It Works
1. Checks your current public IP every 12 hours
2. Compares with AWS Security Group rules
3. If IP changed:
   - Revokes old IP rules (ports 22, 53, 80, 5005)
   - Authorizes new IP rules
4. Logs all changes

**View Logs:**
```bash
tail -f /tmp/ip_updater.log
```

---

## Maintenance Tasks

### Update Pi-hole

```bash
# SSH into server
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP>

# Update Pi-hole
docker exec pihole pihole -up

# Or pull latest image and restart
cd ~/pihole-devops-project/docker
docker compose pull pihole
docker compose up -d pihole
```

### Update Blocklists

```bash
# SSH into server
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP>

# Update gravity (blocklists)
docker exec pihole pihole -g
```

### Backup Pi-hole Configuration

```bash
# From local machine
scp -i terraform/pihole_key -r \
  ubuntu@<EC2_PUBLIC_IP>:~/pihole-devops-project/docker/etc-pihole \
  ./backup-$(date +%Y%m%d)
```

### Restore Configuration

```bash
# From local machine
scp -i terraform/pihole_key -r \
  ./backup-20251212/etc-pihole \
  ubuntu@<EC2_PUBLIC_IP>:~/pihole-devops-project/docker/

# Restart Pi-hole
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker restart pihole"
```

### View Resource Usage

```bash
# SSH into server
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP>

# Docker stats
docker stats --no-stream

# System resources
htop  # or: top
df -h  # Disk usage
free -h  # Memory usage
```

---

## Troubleshooting

### Issue: Can't Access Web Interface

**Check 1: Is Pi-hole running?**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker ps | grep pihole"
```

**Check 2: Is your IP whitelisted?**
```bash
# Get your current IP
curl https://checkip.amazonaws.com

# Update Security Group
cd terraform
terraform apply
```

**Check 3: Check Pi-hole logs**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker logs pihole --tail 50"
```

### Issue: DNS Queries Not Working

**Check 1: Is port 53 open?**
```bash
# From local machine
nc -zv <EC2_PUBLIC_IP> 53
```

**Check 2: Is Pi-hole listening?**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "sudo netstat -tulpn | grep :53"
```

**Check 3: Test DNS directly**
```bash
dig @<EC2_PUBLIC_IP> google.com +short
```

### Issue: Webhook API Not Responding

**Check 1: Is python-monitor running?**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker ps | grep python-monitor"
```

**Check 2: Check logs**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker logs python-monitor"
```

**Check 3: Test locally on server**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "curl http://localhost:5005/stats"
```

### Issue: High CPU/Memory Usage

**Check container stats:**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> "docker stats --no-stream"
```

**Restart containers:**
```bash
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP> \
  "cd ~/pihole-devops-project/docker && docker compose restart"
```

---

## Advanced Usage

### Custom Blocklists

Add custom blocklists via the web interface:
1. Go to Group Management → Adlists
2. Add list URL (e.g., `https://example.com/blocklist.txt`)
3. Click "Add"
4. Update gravity: `docker exec pihole pihole -g`

### CNAME Records

Add custom DNS records:
```bash
# SSH into server
ssh -i terraform/pihole_key ubuntu@<EC2_PUBLIC_IP>

# Add CNAME
docker exec pihole pihole -a addcname myserver.local server.example.com
```

### Conditional Forwarding

Forward specific domains to different DNS servers:
1. Web Interface → Settings → DNS
2. Scroll to "Conditional Forwarding"
3. Enable and configure

---

**Next:** [Architecture](ARCHITECTURE.md) | [Cheat Sheet](cheat_sheet.md)
