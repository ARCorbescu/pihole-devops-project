# Command Cheat Sheet

Quick reference for common commands. Bookmark this page!

---

## 🚀 Quick Start

```bash
# Full deployment (from scratch)
cd terraform && terraform init && terraform apply
cd ../ansible && ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

---

## 📦 Terraform Commands

| Task | Command | Description |
|------|---------|-------------|
| **Initialize** | `terraform init` | Download providers, initialize backend |
| **Preview** | `terraform plan` | Show what will change |
| **Deploy** | `terraform apply` | Create/update infrastructure |
| **Auto-approve** | `terraform apply -auto-approve` | Skip confirmation prompt |
| **Destroy** | `terraform destroy` | Delete ALL resources |
| **Show state** | `terraform show` | Display current state |
| **Output** | `terraform output` | Show output values |
| **Format** | `terraform fmt` | Format `.tf` files |
| **Validate** | `terraform validate` | Check syntax |

### Troubleshooting: Resource Conflicts
If you see error messages like `The keypair already exists` or `The security group 'allow_ssh' already exists`:

1.  **Find the existing IDs:**
    ```bash
    # Get Security Group ID
    aws ec2 describe-security-groups --group-names allow_ssh --query "SecurityGroups[0].GroupId" --output text
    ```
2.  **Import them into Terraform:**
    ```bash
    # Replace <SG_ID> with the ID from the previous step
    terraform import aws_key_pair.deployer pihole-key
    terraform import aws_security_group.allow_ssh <SG_ID>
    ```
3.  **Resume apply:**
    ```bash
# Destroy specific resource
terraform destroy -target=aws_instance.pihole-testing

# Apply only specific resource
terraform apply -target=aws_security_group.allow_ssh
    ```

---

## 🎭 Ansible Commands

### Playbook Execution
```bash
# Run playbook
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass

# Dry run (check mode)
ansible-playbook -i inventory.ini playbook.yml --check

# Run specific role
ansible-playbook -i inventory.ini playbook.yml --tags "pihole-start-services"

# Verbose output
ansible-playbook -i inventory.ini playbook.yml -vvv
```

### Vault Management
```bash
# Encrypt file
ansible-vault encrypt vault.yml

# Decrypt file
ansible-vault decrypt vault.yml

# Edit encrypted file
ansible-vault edit vault.yml

# View encrypted file
ansible-vault view vault.yml

# Change vault password
ansible-vault rekey vault.yml
```

### Ansible Galaxy
```bash
# Install role
ansible-galaxy install geerlingguy.docker

# Install from requirements file
ansible-galaxy install -r requirements.yml

# List installed roles
ansible-galaxy list
```

---

## 🐳 Docker Commands (on EC2)

### Container Management
```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# View container logs
docker logs pihole
docker logs python-monitor
docker logs bash-monitor

# Follow logs (real-time)
docker logs -f pihole

# Restart container
docker restart pihole

# Stop container
docker stop pihole

# Remove container
docker rm pihole

# Execute command in container
docker exec pihole pihole -v
```

### Docker Compose
```bash
# Start all services
cd ~/pihole-devops-project/docker
docker compose up -d

# Stop all services
docker compose down

# Restart all services
docker compose restart

# View logs
docker compose logs -f

# Pull latest images
docker compose pull

# Rebuild images
docker compose build

# View service status
docker compose ps
```

### Resource Monitoring
```bash
# Container stats (real-time)
docker stats

# Container stats (snapshot)
docker stats --no-stream

# Disk usage
docker system df

# Clean up unused resources
docker system prune -a
```

---

## 🔌 SSH & Connectivity

### SSH Access
```bash
# Connect to EC2
ssh -i terraform/pihole_key ubuntu@<IP>

# Execute remote command
ssh -i terraform/pihole_key ubuntu@<IP> "docker ps"

# Copy file to server
scp -i terraform/pihole_key file.txt ubuntu@<IP>:/home/ubuntu/

# Copy file from server
scp -i terraform/pihole_key ubuntu@<IP>:/path/to/file.txt ./
```

### Get EC2 IP
```bash
# From Terraform
cd terraform
terraform output -json | jq -r '.instance_public_ip.value'

# From AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=PiHole - AWS" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].PublicIpAddress" \
  --output text

# From inventory file
cat ansible/inventory.ini | grep -oP '\d+\.\d+\.\d+\.\d+'
```

---

## 🕵️ Testing & Verification

### DNS Testing
```bash
# Test DNS resolution
dig @<EC2_IP> google.com +short

# Test ad blocking
dig @<EC2_IP> ads.google.com +short
# Should return 0.0.0.0

# Test from server itself
ssh -i terraform/pihole_key ubuntu@<IP> "dig @127.0.0.1 google.com +short"

# Check DNS server response time
dig @<EC2_IP> google.com | grep "Query time"
```

### HTTP Testing
```bash
# Test web interface
curl -I http://<EC2_IP>/admin/
# Should return HTTP 200 or 302

# Test webhook API
curl http://<EC2_IP>:5005/stats | jq

# Test with authentication
curl -u admin:<PASSWORD> http://<EC2_IP>/admin/api.php
```

### Port Testing
```bash
# Check if port is open
nc -zv <EC2_IP> 53
nc -zv <EC2_IP> 80
nc -zv <EC2_IP> 5005

# Scan all open ports
nmap <EC2_IP>
```

---

## 🛠️ Pi-hole Management

### Pi-hole CLI (via Docker)
```bash
# Show Pi-hole version
docker exec pihole pihole -v

# Update Pi-hole
docker exec pihole pihole -up

# Update blocklists (gravity)
docker exec pihole pihole -g

# Whitelist domain
docker exec pihole pihole -w example.com

# Blacklist domain
docker exec pihole pihole -b ads.example.com

# Show lists
docker exec pihole pihole -l

# Disable Pi-hole for 5 minutes
docker exec pihole pihole disable 5m

# Enable Pi-hole
docker exec pihole pihole enable

# Show query log
docker exec pihole pihole -t

# Show top blocked domains
docker exec pihole pihole -c
```

### Configuration
```bash
# Edit Pi-hole config
ssh -i terraform/pihole_key ubuntu@<IP>
docker exec -it pihole nano /etc/pihole/pihole.toml

# Restart after config change
docker restart pihole

# View current config
docker exec pihole cat /etc/pihole/pihole.toml
```

---

## 🔄 Maintenance Tasks

### Backup
```bash
# Backup Pi-hole config
scp -i terraform/pihole_key -r \
  ubuntu@<IP>:~/pihole-devops-project/docker/etc-pihole \
  ./backup-$(date +%Y%m%d)

# Backup entire project
ssh -i terraform/pihole_key ubuntu@<IP> \
  "tar -czf /tmp/pihole-backup.tar.gz ~/pihole-devops-project"
scp -i terraform/pihole_key ubuntu@<IP>:/tmp/pihole-backup.tar.gz ./
```

### Restore
```bash
# Restore Pi-hole config
scp -i terraform/pihole_key -r \
  ./backup-20251212/etc-pihole \
  ubuntu@<IP>:~/pihole-devops-project/docker/

# Restart Pi-hole
ssh -i terraform/pihole_key ubuntu@<IP> "docker restart pihole"
```

### Updates
```bash
# Update Docker images
ssh -i terraform/pihole_key ubuntu@<IP> \
  "cd ~/pihole-devops-project/docker && docker compose pull && docker compose up -d"

# Update system packages
ssh -i terraform/pihole_key ubuntu@<IP> \
  "sudo apt update && sudo apt upgrade -y"
```

---

## 🔧 Utilities

### Dynamic IP Updater
```bash
# Run manually
python3 scripts/update_ip.py

# Run in background
nohup python3 scripts/update_ip.py > /tmp/ip_updater.log 2>&1 &

# Check if running
ps aux | grep update_ip.py

# View logs
tail -f /tmp/ip_updater.log

# Kill process
pkill -f update_ip.py
```

### System Monitoring
```bash
# View system resources
ssh -i terraform/pihole_key ubuntu@<IP> "htop"

# Check disk usage
ssh -i terraform/pihole_key ubuntu@<IP> "df -h"

# Check memory usage
ssh -i terraform/pihole_key ubuntu@<IP> "free -h"

# Check network connections
ssh -i terraform/pihole_key ubuntu@<IP> "sudo netstat -tulpn"
```

---

## 🐛 Troubleshooting

### View Logs
```bash
# Pi-hole logs
docker logs pihole --tail 100

# Python monitor logs
docker logs python-monitor --tail 50

# Bash monitor logs
docker logs bash-monitor --tail 50

# System logs
ssh -i terraform/pihole_key ubuntu@<IP> "sudo journalctl -xe"

# Docker daemon logs
ssh -i terraform/pihole_key ubuntu@<IP> "sudo journalctl -u docker"
```

### Restart Services
```bash
# Restart Pi-hole
docker restart pihole

# Restart all containers
cd ~/pihole-devops-project/docker
docker compose restart

# Restart Docker daemon
sudo systemctl restart docker
```

### Check Service Status
```bash
# Check if Pi-hole is running
docker ps | grep pihole

# Check if port 53 is listening
sudo netstat -tulpn | grep :53

# Check DNS resolution
dig @127.0.0.1 google.com +short
```

---

## 📊 Monitoring

### Real-time Stats
```bash
# Docker stats
docker stats

# System stats
htop

# Network stats
iftop

# Disk I/O
iotop
```

### Webhook API
```bash
# Get Pi-hole stats
curl http://<EC2_IP>:5005/stats | jq

# Pretty print
curl -s http://<EC2_IP>:5005/stats | jq '.'

# Get specific field
curl -s http://<EC2_IP>:5005/stats | jq '.ads_blocked_today'

# Watch stats (refresh every 5s)
watch -n 5 'curl -s http://<EC2_IP>:5005/stats | jq'
```

---

## 🔐 Security

### Update Security Group
```bash
# Get your current IP
curl https://checkip.amazonaws.com

# Update Terraform
cd terraform
# Edit main.tf with new IP
terraform apply
```

---

## 🔐 Security & SSH Keys

### Fixing "Unprotected Private Key" (Permissions)
If SSH/Ansible complains that permissions are "too open" (e.g., 0644):
```bash
# Generate new key
ssh-keygen -t ed25519 -f pihole_key_v2 -N ""

# Set permissions to owner-read-only
chmod 400 terraform/pihole_key_v2

# Update Terraform
cd terraform

# Update main.tf to use new key
terraform apply

# Test new key
ssh -i pihole_key_v2 ubuntu@<IP>
```

### Rotating SSH Keys
To generate a new key and update the infrastructure:
1.  **Generate new key pair:**
    ```bash
    cd terraform
    ssh-keygen -t ed25519 -f pihole_key_v3 -N ""
    chmod 400 pihole_key_v3
    ```
2.  **Update `main.tf`**: Change `key_name` and the `public_key` file reference.
3.  **Update `inventory.tf`**: Change the `ansible_ssh_private_key_file` path.
4.  **Apply changes**:
    ```bash
    terraform apply -auto-approve
    ```
    *Note: This will recreate the EC2 instance to inject the new key.*

---

## 📚 Reference

### File Locations (on EC2)
```
/home/ubuntu/pihole-devops-project/     # Project root
/home/ubuntu/pihole-devops-project/docker/etc-pihole/    # Pi-hole config
/home/ubuntu/pihole-devops-project/docker/etc-dnsmasq.d/ # DNS config
/var/lib/docker/                        # Docker data
/etc/resolv.conf                        # System DNS config
```

### Important URLs
- **Pi-hole Web UI**: `http://<EC2_IP>/admin`
- **Webhook API**: `http://<EC2_IP>:5005/stats`
- **Pi-hole Docs**: https://docs.pi-hole.net
- **Docker Docs**: https://docs.docker.com

---

### Test DNS Resolution
```bash
# Test DNS resolution
dig @<EC2_IP> google.com +short
```

### Test ad blocking
```bash
dig @<EC2_IP> ads.google.com +short
```

---

**Pro Tip:** Add these aliases to your `~/.bashrc` or `~/.zshrc`:

```bash
alias pihole-ssh='ssh -i ~/pihole-devops-project/terraform/pihole_key ubuntu@<IP>'
alias pihole-logs='ssh -i ~/pihole-devops-project/terraform/pihole_key ubuntu@<IP> "docker logs -f pihole"'
alias pihole-stats='curl -s http://<IP>:5005/stats | jq'
```

---

**See also:** [Installation](INSTALLATION.md) | [Usage](USAGE.md) | [Architecture](ARCHITECTURE.md) | [Deployment Walkthrough](DEPLOYMENT_WALKTHROUGH.md)
