# Architecture Documentation

Technical deep-dive into the Pi-hole DevOps project architecture, design decisions, and lessons learned.

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Infrastructure Layer (Terraform)](#infrastructure-layer-terraform)
3. [Configuration Layer (Ansible)](#configuration-layer-ansible)
4. [Application Layer (Docker)](#application-layer-docker)
5. [Design Decisions](#design-decisions)
6. [Problems & Solutions](#problems--solutions)
7. [Security Architecture](#security-architecture)

---

## System Overview

### Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                      LOCAL MACHINE                          │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │  Terraform   │────────▶│   Ansible    │                  │
│  │  (Provision) │         │  (Configure) │                  │
│  └──────────────┘         └──────────────┘                  │
│         │                         │                         │
│         │ SSH                     │ SSH                     │
│         ▼                         ▼                         │
└─────────────────────────────────────────────────────────────┘
          │                         │
          │                         │
          ▼                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS EC2 INSTANCE                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Docker Compose Stack                    │   │
│  │  ┌────────────┐  ┌─────────────┐  ┌──────────────┐   │   │
│  │  │  Pi-hole   │  │ Bash Monitor│  │Python Monitor│   │   │
│  │  │ (Port 53)  │  │             │  │  (Port 5005) │   │   │
│  │  │ (Port 80)  │  │             │  │              │   │   │
│  │  └────────────┘  └─────────────┘  └──────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Host OS (Ubuntu 22.04)                       │   │
│  │  - systemd-resolved: DISABLED                        │   │
│  │  - /etc/resolv.conf → 127.0.0.1                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
          ▲
          │ DNS Queries (Port 53)
          │ HTTP Access (Port 80)
          │ Webhook API (Port 5005)
          │
    ┌─────┴─────┐
    │  Internet │
    │  (Your IP)│
    └───────────┘
```

### Technology Stack
| Layer | Technology | Purpose |
|-------|------------|---------|
| **Infrastructure** | Terraform | Provision AWS resources |
| **Configuration** | Ansible | Install software, configure system |
| **Containerization** | Docker Compose | Run Pi-hole and monitoring services |
| **DNS Server** | Pi-hole v6 | Ad-blocking DNS resolver |
| **Monitoring** | Bash + Python | System metrics and Pi-hole stats |
| **Secrets** | Ansible Vault | Encrypt sensitive data |

---

## Infrastructure Layer (Terraform)

### Resources Created

#### 1. EC2 Instance
```hcl
resource "aws_instance" "pihole" {
  ami           = data.aws_ami.ubuntu.id  # Ubuntu 22.04 LTS
  instance_type = "t3.micro"              # Free tier eligible
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
}
```

**Why t3.micro?**
- Free tier eligible (750 hours/month)
- Sufficient for Pi-hole (1 vCPU, 1GB RAM)
- Available in `eu-north-1` (Stockholm)

#### 2. Security Group
```hcl
resource "aws_security_group" "allow_ssh" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # Whitelisted IP only
  }
  # ... (ports 53, 80, 5005)
}
```

**Ports Exposed:**
| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 22 | TCP | SSH | Your IP only |
| 53 | TCP/UDP | DNS | Your IP only |
| 80 | TCP | Pi-hole Web UI | Your IP only |
| 5005 | TCP | Webhook API | Your IP only |

#### 3. SSH Key Pair
```hcl
resource "aws_key_pair" "deployer" {
  key_name   = "pihole-key"
  public_key = file("${path.module}/pihole_key.pub")
}
```

Generated locally with:
```bash
ssh-keygen -t ed25519 -f pihole_key -N ""
```

#### 4. Dynamic Inventory
```hcl
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [pihole_servers]
    ${aws_instance.pihole.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/pihole_key
  EOT
  filename = "${path.module}/../ansible/inventory.ini"
}
```

**Why dynamic inventory?**
- EC2 public IP changes on each `terraform apply`
- Ansible automatically gets the correct IP
- No manual configuration needed

---

## Configuration Layer (Ansible)

### Role-Based Architecture

The deployment is split into **6 modular roles**, each with a single responsibility:

```
ansible/roles/
├── pihole-system-setup/       # Install system dependencies
├── geerlingguy.docker/        # Install Docker (external role)
├── pihole-clone-repo/         # Clone project from GitHub
├── pihole-docker-deployment/  # Pull & build Docker images
├── pihole-disable-dns/        # Disable systemd-resolved
└── pihole-start-services/     # Start Pi-hole containers
```

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. pihole-system-setup                                      │
│    └─ Install: git, curl, ca-certificates                   │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. geerlingguy.docker                                       │
│    └─ Install: Docker, Docker Compose, add user to group    │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. pihole-clone-repo                                        │
│    └─ git clone https://github.com/ARCorbescu/...           │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. pihole-docker-deployment                                 │
│    ├─ docker compose pull  (while DNS still works!)         │
│    └─ docker compose build                                  │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. pihole-disable-dns                                       │
│    ├─ systemctl stop systemd-resolved                       │
│    ├─ systemctl disable systemd-resolved                    │
│    ├─ rm /etc/resolv.conf                                   │
│    └─ echo "nameserver 127.0.0.1" > /etc/resolv.conf        │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. pihole-start-services                                    │
│    ├─ docker compose up -d                                  │
│    ├─ Wait 10 seconds                                       │
│    ├─ docker exec pihole sed -i 's/LOCAL/ALL/' pihole.toml  │
│    └─ docker restart pihole                                 │
└─────────────────────────────────────────────────────────────┘
```

### "Pull-First" Strategy

**The Problem:**
If we disable `systemd-resolved` before pulling Docker images, the host loses DNS resolution and `docker pull` fails.

**The Solution:**
1. Pull/build images **while system DNS still works**
2. **Then** disable `systemd-resolved`
3. **Then** start Pi-hole (which takes over port 53)

This is why roles 4 and 5 are separate!

---

## Application Layer (Docker)

### Docker Compose Services

```yaml
services:
  pihole:
    image: pihole/pihole:latest
    network_mode: host  # Direct access to host network
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    environment:
      FTLCONF_webserver_api_password: "${PIHOLE_PASSWORD}"
      DNSMASQ_LISTENING: "all"  # Accept queries from any IP
    volumes:
      - ./etc-pihole:/etc/pihole
      - ./etc-dnsmasq.d:/etc/dnsmasq.d

  python-monitor:
    build:
      context: ..
      dockerfile: docker/Dockerfile.monitor-python
    ports:
      - "5005:5005"
    environment:
      PIHOLE_URL: "http://172.17.0.1"
      PIHOLE_API_KEY: "${PIHOLE_PASSWORD}"

  bash-monitor:
    build:
      context: ..
      dockerfile: docker/Dockerfile.monitor-bash
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### Why `network_mode: host`?
- Pi-hole needs to bind to port 53 on the **host's IP**
- Bridge networking would only expose it on the Docker network
- Host mode makes Pi-hole accessible from the internet

---

## Design Decisions

### 1. Terraform + Ansible Split

**Why not just Terraform?**
- Terraform is great for infrastructure, but awkward for configuration
- Ansible is purpose-built for software installation and configuration
- Separation of concerns: Terraform = "What to create", Ansible = "How to configure"

**Why not just Ansible?**
- Ansible's AWS modules are less mature than Terraform
- Terraform has better state management for infrastructure
- Terraform's `plan` feature prevents accidental deletions

### 2. Modular Ansible Roles

**Why split into 6 roles instead of one monolithic playbook?**
- **Reusability**: Roles can be used in other projects
- **Testability**: Each role can be tested independently
- **Maintainability**: Easier to understand and modify
- **Debugging**: Failures are isolated to specific roles

### 3. External Role (`geerlingguy.docker`)

**Why not write our own Docker installation role?**
- Don't reinvent the wheel
- `geerlingguy.docker` is battle-tested (1000+ stars on GitHub)
- Handles edge cases we might miss
- Automatically updated by the community

### 4. Ansible Vault for Secrets

**Why not environment variables?**
- Vault files can be committed to Git (encrypted)
- Centralized secret management
- Built-in encryption/decryption
- No risk of secrets in shell history

### 5. Dynamic IP Updater Script

**Why a separate Python script instead of Terraform?**
- Terraform doesn't run continuously
- Python script can run in the background (12-hour loop)
- Uses AWS CLI directly (simpler than Terraform)
- Trade-off: Causes Terraform state drift (acceptable)

---

## Problems & Solutions

### Problem 1: Port 53 Conflict
**Issue:** Ubuntu's `systemd-resolved` already uses port 53.

**Working Solution:**
Fully disable `systemd-resolved` and point `/etc/resolv.conf` to `127.0.0.1`:
```bash
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf
```

**Trade-off:** If Pi-hole crashes, the host loses DNS.

### Problem 2: Docker Build Fails After Disabling DNS
**Issue:** `docker compose build` needs DNS to pull base images.

**Solution:** "Pull-First" strategy - pull/build **before** disabling DNS.

### Problem 3: Pi-hole v6 Rejects External Queries
**Issue:** Pi-hole v6 defaults to `listeningMode = "LOCAL"`.

**Solution:** Modify `/etc/pihole/pihole.toml` after container starts:
```bash
docker exec pihole sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml
docker restart pihole
```

** This can also be fixed from the UI **
<img width="1301" height="811" alt="image" src="https://github.com/user-attachments/assets/071b6154-347e-4a9c-a831-569363c8ec06" />


### Problem 4: Dynamic IP Changes
**Issue:** User's home IP changes, breaking Security Group rules.

**Solution:** Python script that:
1. Checks current public IP every 12 hours
2. Compares with Security Group rules
3. Revokes old IP rules
4. Authorizes new IP rules

---

## Security Architecture

### Defense in Depth

| Layer | Mechanism | Protection |
|-------|-----------|------------|
| **Network** | AWS Security Group | Only whitelisted IP can connect |
| **Transport** | SSH Key Authentication | No password-based login |
| **Application** | Pi-hole Password | Web UI requires authentication |
| **Data** | Ansible Vault | Secrets encrypted at rest |

### Attack Surface

**Exposed Services:**
- SSH (Port 22) - Protected by key authentication
- DNS (Port 53) - Pi-hole handles queries
- HTTP (Port 80) - Pi-hole web UI (password-protected)
- Webhook (Port 5005) - Read-only statistics API

**Mitigations:**
- All ports restricted to user's IP only
- No public-facing services
- Regular updates via `docker pull`

### Security Best Practices

✅ **Implemented:**
- IP whitelisting
- SSH key authentication
- Encrypted secrets (Ansible Vault)
- Minimal exposed ports
- Regular security updates

❌ **Not Implemented (Future Improvements):**
- HTTPS/TLS (currently HTTP only)
- Fail2ban (SSH brute-force protection)
- CloudWatch monitoring
- Automated backups

---

## Performance Considerations

### Resource Usage
- **CPU**: ~5-10% idle, ~20% under load
- **RAM**: ~400MB (Pi-hole + monitors)
- **Disk**: ~2GB (Docker images + logs)
- **Network**: Minimal (DNS queries are tiny)

### Scaling Limitations
- Single EC2 instance (no high availability)
- No load balancing
- Manual failover required

**For Production:**
- Use Auto Scaling Group
- Add Application Load Balancer
- Implement health checks
- Use RDS for persistent storage

---

## Lessons Learned

### What Worked Well
✅ Terraform + Ansible split architecture  
✅ Modular Ansible roles  
✅ "Pull-First" deployment strategy  
✅ Dynamic inventory generation  
✅ Ansible Vault for secrets  

### What Could Be Improved
⚠️ No automated testing (should add Molecule tests)  
⚠️ No CI/CD pipeline (should add GitHub Actions)  
⚠️ No monitoring/alerting (should add CloudWatch)  
⚠️ No HTTPS (should add Let's Encrypt)  

### Key Takeaways
1. **DNS is hard** - Many edge cases and conflicts
2. **Order matters** - Pull images before breaking DNS
3. **Modularity wins** - Small, focused roles are easier to debug
4. **External roles save time** - Don't reinvent Docker installation
5. **Documentation is crucial** - Future you will thank you

---

**Next:** [Usage Guide](USAGE.md) | [Cheat Sheet](cheat_sheet.md)
