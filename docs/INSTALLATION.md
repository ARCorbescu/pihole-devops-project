# Installation Guide

## Prerequisites
- **Terraform** (v1.5+)
- **Ansible** (v2.10+)
- **AWS CLI** (Configured with credentials)
- **Python 3**

## 1. Local Setup
Clone the repository and install dependencies.
```bash
git clone https://github.com/ARCorbescu/pihole-devops-project.git
cd pihole-devops-project
```

## 2. Infrastructure (Terraform)
Provision the AWS EC2 instance and Security Groups.
```bash
cd terraform

# Initialize providers
terraform init

# Apply infrastructure (Type 'yes' to confirm)
terraform apply
```
*Note: This will automatically generate `../ansible/inventory.ini`.*

## 3. Configuration (Ansible)
Deploy the software stack (Docker, Pi-hole, Monitoring).

### 3.1 Setup Secrets
You must create the encrypted vault file for the Pi-hole password.
```bash
cd ../ansible

# Encrypt the vault file (Enter a strong password when prompted)
ansible-vault encrypt vault.yml
```

### 3.2 Run Playbook
Deploy the application.
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

## 4. Verification
Check if the services are running.
```bash
# Check Docker on the remote server
ssh -i ../terraform/pihole_key ubuntu@<IP_FROM_INVENTORY> "docker ps"
```
