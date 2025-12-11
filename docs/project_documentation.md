# Project: AWS Pi-hole with Terraform

## 1. Project Goal
Learn AWS and Terraform by provisioning an EC2 instance and automatically deploying a Pi-hole DNS server using Infrastructure as Code (IaC).

## 2. Infrastructure Setup (Terraform)
We defined our infrastructure in `main.tf` and `provider.tf`.

### Key Resources
1.  **Provider**: AWS (Region: `eu-north-1`).
2.  **EC2 Instance**: `t3.micro` (Ubuntu 22.04 LTS).
3.  **Security Group**: `allow_ssh_http_dns`.
    - **Ports Enabled**: 22 (SSH), 80 (HTTP), 53 (DNS TCP/UDP).
    - **Security Rule**: Restricted to **User's IP Address Only** (`81.196.215.162/32`) to prevent unauthorized access.
4.  **SSH Key Pair**: Dedicated `pihole_key` for secure access.

### Automation (Ansible)
We switched from a simple shell script to Ansible for better configuration management.
1.  **Roles**:
    -   `common`: Installs Docker, Git, and system dependencies.
    -   `pihole`: Handles application deployment and configuration.
2.  **Smart Deployment ("Pull-First")**:
    -   Pulls Docker images *before* disabling system DNS to prevent connection errors.
    -   Disables `systemd-resolved` to free up Port 53.
    -   Deploys Pi-hole and configures it to listen on all interfaces.
3.  **Secrets**: Sensitive data (passwords) are encrypted using **Ansible Vault**.

## 3. Project Structure
```
.
├── terraform/          # Infrastructure (EC2, Firewall, Inventory Gen)
│   ├── main.tf
│   ├── inventory.tf
│   └── ...
├── ansible/            # Configuration Management
│   ├── playbook.yml
│   ├── vault.yml       # Encrypted Secrets
│   └── roles/
│       ├── common/     # System Setup
│       └── pihole/     # App Deployment
├── scripts/
│   └── update_ip.py    # IP Drift Auto-fixer
└── docs/               # Documentation
    ├── INSTALLATION.md
    ├── USAGE.md
    └── ...
```

## 4. Problems Encountered & Solutions

### 1. AWS Region Mismatch
**Problem**: Terraform defaults to `us-east-1`, but we wanted to deploy in Europe (`eu-north-1`).
**Solution**: We explicitly configured the `region` in `provider.tf` to `eu-north-1`.

### 2. EC2 Instance Type Availability
**Problem**: The standard `t2.micro` instance was not available in our specific Availability Zone in Stockholm.
**Solution**: We switched to `t3.micro`, which is also Free Tier eligible and available in the region.

### 3. Port 53 Conflict (systemd-resolved)
**Problem**: Pi-hole failed to start because port 53 was already in use by Ubuntu's built-in DNS stub listener (`systemd-resolved`).
**Solution**: We added a step in `install_docker.sh` to disable `DNSStubListener` in `/etc/systemd/resolved.conf` and restart the service.

### 4. Docker DNS Resolution Failure
**Problem**: Disabling the stub listener (to fix Port 53) inadvertently broke DNS for the host itself. Docker could not resolve `docker.io` to pull images, failing with `connection refused` on `127.0.0.53:53`.
**Solution**: We forced the system to use upstream AWS DNS servers by symlinking `/etc/resolv.conf` to `/run/systemd/resolve/resolv.conf` and then restarting the Docker daemon to pick up the change.

### 5. Pi-hole Rejecting External Queries (v6)
**Problem**: Even with ports open, Pi-hole v6 ignored queries from the internet (`ignoring query from non-local network`) because it defaults to "Local Mode" for security. The command `pihole -a -i all` (used in older versions) does not work in v6.
**Solution**: We manually edited `/etc/pihole/pihole.toml` to set `listeningMode = "ALL"` and restarted the container.

### 6. Security Risks
**Problem**: Enabling "Permit All Origins" makes the server vulnerable to DNS Amplification attacks if exposed to the entire internet.
**Solution**: We used AWS Security Groups in `main.tf` to strict ingress rules, allowing traffic **only** from your specific IP address (`81.196.215.162/32`).
### 7. Dynamic IP Drift
**Problem**: The user's home IP address is dynamic and changes periodically. Since the AWS Security Group is restricted to only this IP, access is lost when the IP changes.
**Solution**: We created a Python script (`scripts/update_ip.py`) that runs locally. It checks the current public IP every 12 hours and uses the AWS CLI (`subprocess`) to automatically update the Security Group rules if a change is detected.
## 5. Security & Maintenance
- **Access Control**: The Security Group currently allows **only your IP**. If your home IP changes, you will lose access. Update `main.tf` and run `terraform apply`.
- **Git**: Project state is saved in a local git repository.
- **Costs**: Run `terraform destroy` when not in use to stop billing.
