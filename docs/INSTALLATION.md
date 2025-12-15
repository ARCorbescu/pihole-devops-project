# Installation Guide

Complete step-by-step guide to deploy Pi-hole on AWS.

---

## Prerequisites

### Required Software
| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| **Terraform** | 1.5.0+ | [terraform.io](https://www.terraform.io/downloads) |
| **Ansible** | 2.10+ | `pip install ansible` |
| **AWS CLI** | 2.0+ | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| **Python** | 3.8+ | [python.org](https://www.python.org/downloads/) |
| **Git** | Any | `apt install git` / `brew install git` |

### AWS Account Setup
1. **Create an AWS Account** (if you don't have one)
2. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, Region (eu-north-1), Output format (json)
   ```
3. **Verify credentials**:
   ```bash
   aws sts get-caller-identity
   ```

### Local Dependencies
```bash
# Install Ansible Galaxy role for Docker
ansible-galaxy install geerlingguy.docker

# Verify installations
terraform --version
ansible --version
python3 --version
```

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/ARCorbescu/pihole-devops-project.git
cd pihole-devops-project
```

---

## Step 2: Configure Secrets (Ansible Vault)

### 2.1 Create Vault File
The `vault.yml` file stores your Pi-hole admin password.

```bash
cd ansible
```

Edit `vault.yml` and set your password:
```yaml
---
pihole_password: "YourSecurePasswordHere"
```

### 2.2 Encrypt the Vault
```bash
ansible-vault encrypt vault.yml
# Enter a strong vault password when prompted
# Remember this password - you'll need it for deployments!
```

### 2.3 Verify Encryption
```bash
cat vault.yml
# Should show encrypted content starting with $ANSIBLE_VAULT;1.1;AES256
```

**Managing Vault:**
```bash
# View encrypted content
ansible-vault view vault.yml

# Edit encrypted file
ansible-vault edit vault.yml

# Decrypt (not recommended for production)
ansible-vault decrypt vault.yml
```

---

## Step 3: Provision AWS Infrastructure (Terraform)

### 3.1 Update Your IP Address
Edit `terraform/main.tf` and update the Security Group rules with **your public IP**:

```hcl
resource "aws_security_group" "allow_ssh" {
  # ...
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR.PUBLIC.IP.HERE/32"]  # ← Change this!
  }
  # ... (repeat for ports 80, 53, 5005)
}
```

**Find your public IP:**
```bash
curl https://checkip.amazonaws.com
```

### 3.2 Initialize Terraform
```bash
cd terraform
terraform init
```

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
Terraform has been successfully initialized!
```

### 3.3 Preview Changes
```bash
terraform plan
```

Review the resources that will be created:
- 1 EC2 instance (`t3.micro`)
- 1 Security Group
- 1 SSH Key Pair
- 1 Local file (`ansible/inventory.ini`)

### 3.4 Apply Infrastructure
```bash
terraform apply
```

Type `yes` when prompted.

**Expected output:**
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

### 3.5 Verify Inventory Generation
```bash
cat ../ansible/inventory.ini
```

Should show:
```ini
[pihole_servers]
<EC2_PUBLIC_IP> ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/pihole_key
```

---

## Step 4: Deploy Pi-hole (Ansible)

### 4.1 Test SSH Connection
```bash
cd ../ansible
ssh -i ../terraform/pihole_key ubuntu@<IP_FROM_INVENTORY> "echo 'Connection successful!'"
```

If you get a "Host key verification" prompt, type `yes`.

### 4.2 Run Ansible Playbook
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

**Enter your vault password** when prompted.

### 4.3 Deployment Process
The playbook will execute these roles in order:

| # | Role | Duration | What It Does |
|---|------|----------|--------------|
| 1 | `pihole-system-setup` | ~10s | Installs git, curl, ca-certificates |
| 2 | `geerlingguy.docker` | ~2min | Installs Docker & Docker Compose |
| 3 | `pihole-clone-repo` | ~5s | Clones project from GitHub |
| 4 | `pihole-docker-deployment` | ~3min | Pulls & builds Docker images |
| 5 | `pihole-disable-dns` | ~5s | Disables systemd-resolved, frees port 53 |
| 6 | `pihole-start-services` | ~30s | Starts Pi-hole, configures v6 settings |

**Total time:** ~6-7 minutes

### 4.4 Expected Output
```
PLAY RECAP *******************************************
<IP>  : ok=30   changed=11   unreachable=0    failed=0
```

---

## Step 5: Verification

### 5.1 Check Docker Containers
```bash
ssh -i ../terraform/pihole_key ubuntu@<IP> "docker ps"
```

**Expected output:**
```
CONTAINER ID   IMAGE                  STATUS         PORTS
abc123...      pihole/pihole:latest   Up 2 minutes   53/tcp, 53/udp, 80/tcp
def456...      python-monitor         Up 2 minutes   5005/tcp
ghi789...      bash-monitor           Up 2 minutes
```

### 5.2 Access Pi-hole Web Interface
Open in your browser:
```
http://<EC2_PUBLIC_IP>/admin
```

**Login:**
- Password: The password you set in `vault.yml`

### 5.3 Test DNS Resolution
```bash
# From your local machine
dig @<EC2_PUBLIC_IP> google.com +short
```

Should return Google's IP addresses.

### 5.4 Test Webhook API
```bash
curl http://<EC2_PUBLIC_IP>:5005/stats
```

Should return JSON with Pi-hole statistics.

---

## Troubleshooting

### Issue: Terraform fails with "InvalidAMIID.NotFound"
**Solution:** The Ubuntu AMI might not be available in your region. Edit `terraform/main.tf` and change the region in `provider.tf`.

### Issue: Ansible fails with "Permission denied (publickey)"
**Solution:** Ensure the SSH key has correct permissions:
```bash
chmod 600 terraform/pihole_key
```

### Issue: Pi-hole web interface shows "403 Forbidden"
**Solution:** Your IP might have changed. Update Security Group:
```bash
cd terraform
terraform apply
```

### Issue: DNS queries timeout
**Solution:** Check if your ISP blocks outbound port 53:
```bash
ssh -i terraform/pihole_key ubuntu@<IP> "sudo docker logs pihole"
```

---

## Next Steps

- [Usage Guide](USAGE.md) - Learn how to use Pi-hole and utilities
- [Architecture](ARCHITECTURE.md) - Understand the technical design
- [Cheat Sheet](cheat_sheet.md) - Quick command reference

---

## Cleanup

To destroy all AWS resources and stop billing:

```bash
cd terraform
terraform destroy
# Type 'yes' to confirm
```

**Warning:** This will permanently delete:
- EC2 instance
- Security Group
- SSH Key Pair
- All Pi-hole data

---

**Installation complete!** 🎉
