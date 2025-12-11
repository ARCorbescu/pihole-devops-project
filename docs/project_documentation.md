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

### Automation (User Data)
The `scripts/install_docker.sh` runs on first boot to:
1.  Install Docker & Compose.
2.  **Fix System DNS**: Relink `/etc/resolv.conf` to upstream AWS DNS and restart Docker (Fixes `connection refused` pulling images).
3.  **Fix Port 53**: Disable `systemd-resolved` stub listener.
4.  Deploy Pi-hole container.
5.  **Configure Pi-hole v6**: Automatically set `listeningMode = "ALL"` in `pihole.toml` to allow non-local queries (required for cloud setup).

## 3. Project Structure
```
.
├── main.tf                 # Infrastructure definition (EC2, SG, Key)
├── provider.tf             # AWS Provider config
├── scripts/
│   └── install_docker.sh   # Automation script (Install & Config)
├── pihole_key              # Private SSH key
├── pihole_key.pub          # Public SSH key
├── documentation.md        # Project documentation
└── cheat_sheet.md          # Quick reference commands
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

## 5. Security & Maintenance
- **Access Control**: The Security Group currently allows **only your IP**. If your home IP changes, you will lose access. Update `main.tf` and run `terraform apply`.
- **Git**: Project state is saved in a local git repository.
- **Costs**: Run `terraform destroy` when not in use to stop billing.
