# Command Cheat Sheet

## 1. Configuration Management (Ansible)
**Run Playbook:**
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

**Manage Secrets (Vault):**
```bash
# Edit encrypted file
ansible-vault edit vault.yml

# View encrypted file
ansible-vault view vault.yml
```

## 2. Infrastructure (Terraform)
Commands to manage the infrastructure lifecycle.

| Action | Command | Description |
| :--- | :--- | :--- |
| **Initialize** | `terraform init` | Downloads providers and sets up state. |
| **Preview** | `terraform plan` | Shows what changes will be made. |
| **Deploy** | `terraform apply` | Creates or updates resources (add `-auto-approve` to skip yes). |
| **Redeploy App** | `terraform taint aws_instance.pihole` | Marks instance for recreation (forcing new User Data run). |
| **Clean Up** | `terraform destroy` | Deletes **ALL** resources (Stop paying). |

## 3. SSH Access & Management
How to connect to your EC2 instance.

**Get Public IP:**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=PiHole - AWS" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].PublicIpAddress" \
  --output text
```

**Connect via SSH:**
```bash
# Replace <public-ip> with the actual IP
ssh -i pihole_key ubuntu@<public-ip>

ssh -i pihole_key ubuntu@$(aws ec2 describe-instances --filters "Name=tag:Name,Values=PiHole - AWS" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

```

**Check Deployment Logs (Server Side):**
```bash
# Verify the User Data script execution
tail -n 50 /var/log/cloud-init-output.log
```

## 4. Testing & Verification
Verify the application is working.

**Check Docker Containers:**
```bash
ssh -i pihole_key ubuntu@<public-ip> "docker ps"

ssh -i pihole_key ubuntu@$(aws ec2 describe-instances --filters "Name=tag:Name,Values=PiHole - AWS" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text) "docker ps"
```

**Test Web Interface:**
```bash
# Should return HTTP 302 or 200
curl -I http://<public-ip>/admin/

curl -I http://$(aws ec2 describe-instances --filters "Name=tag:Name,Values=PiHole - AWS" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text)/admin/
```

**Test DNS Resolution (Local on Server):**
```bash
# Useful to verify Pi-hole is actually listening
ssh -i pihole_key ubuntu@<public-ip> "dig @127.0.0.1 google.com +short"

dig @$(aws ec2 describe-instances --filters "Name=tag:Name,Values=PiHole - AWS" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text) google.com +short
```

**Test DNS Resolution (From your laptop):**
```bash
# Warning: Often blocked by residential ISPs
dig @<public-ip> google.com +short

dig @$(aws ec2 describe-instances --filters "Name=tag:Name,Values=PiHole - AWS" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text) google.com +short
```

## 6. Utilities
**Dynamic IP Updater:**
```bash
# Run manually
python3 scripts/update_ip.py

# Run in background (12h interval)
nohup python3 scripts/update_ip.py &
```

## 5. Key Setup Commands (One-time)
These were used during the initial setup.

**Generate SSH Key:**
```bash
ssh-keygen -t ed25519 -f pihole_key -N ""
```
