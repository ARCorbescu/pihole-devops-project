# Deployment Walkthrough & Troubleshooting

This document provides a line-by-line breakdown of the Pi-hole deployment process, explaining what happens "under the hood" during the Ansible execution.

---

## 🚀 The Deployment Lifecycle

When you run `ansible-playbook -i inventory.ini playbook.yml`, the system goes through 6 major phases.

### Phase 1: Gathering Facts
**Log Output:** `TASK [Gathering Facts] ***`
- **What it does**: Connects via SSH and detects the OS, IP addresses, and hardware specs of the EC2 instance. 
- **Key Insight**: It identifies our target as `Ubuntu 22.04` (Jammy), which tells the subsequent roles which package managers and paths to use.

### Phase 2: System Dependencies (`pihole-system-setup`)
**Log Output:** `TASK [pihole-system-setup : Install dependencies] ***`
- **What it does**: Installs `git`, `curl`, `ca-certificates`, and `python3-pip`.
- **Why**: These are the "tools for the tools." We need Git to clone the project and PIP to manage Python monitors.

### Phase 3: Docker Installation (`geerlingguy.docker`)
**Log Output:** `RUNNING HANDLER [geerlingguy.docker : apt update] ***`
- **What it does**: 
  1. Adds the official Docker GPG key and repository.
  2. Installs `docker-ce`, `docker-compose-plugin`.
  3. Adds the `ubuntu` user to the `docker` group.
- **Why**: Using a containerized approach ensures our Pi-hole setup is isolated and easy to update.

### Phase 4: Application Code (`pihole-clone-repo`)
**Log Output:** `TASK [pihole-clone-repo : Clone Pi-hole Project] ***`
- **What it does**: Downloads the latest version of this repository directly onto the EC2 instance.
- **Location**: `/home/ubuntu/pihole-devops-project/`

### Phase 5: The "Port 53" Battle (`pihole-disable-dns`)
**Log Output:** `TASK [pihole-disable-dns : Stop and Disable systemd-resolved] ***`
- **The Problem**: By default, Ubuntu runs `systemd-resolved` on port 53. Since two services cannot use the same port, Pi-hole would fail to start.
- **The Solution**: 
  1. **Stop/Disable systemd-resolved**: Frees up port 53.
  2. **Modify `/etc/resolv.conf`**: Points the host machine to its own local IP (`127.0.0.1`).
- **Critical Order**: We pull the Docker images *before* this task so that the machine still has internet access to download them!

### Phase 6: Orchestration (`pihole-start-services`)
**Log Output:** `TASK [pihole-start-services : Start Pi-hole Services] ***`
- **What it does**: Runs the command `docker compose up -d` directly on the server.
- **Environment**: It passes the `PIHOLE_PASSWORD` from your vault into the process so the containers can use it.
- **Containers Started**:
  1. **pihole**: The DNS engine (FTL).
  2. **bash-monitor**: Logs system health (CPU/RAM).
  3. **python-monitor**: Provides the Webhook API for statistics.
- **Post-Start Hook**: After starting the stack, Ansible runs a `docker exec` command to modify `pihole.toml`, switching the `listeningMode` to `ALL`. This ensures the DNS server is reachable from your home IP.

---

## 🔍 Post-Deployment Verification

After a successful run (`changed=10`, `failed=0`), you can verify the state by running these commands on the server:

### 1. Check Service Health
```bash
docker ps
```
*Expectation: 3 containers running, Pi-hole status should be "(healthy)".*

### 2. Verify Port 53 Ownership
```bash
sudo netstat -tulpn | grep :53
```
*Expectation: The process `pihole-FTL` should be listening.*

### 3. Test Internal Resolution
```bash
dig @localhost google.com +short
```
*Expectation: A valid IP address should return immediately.*

---

## 🐛 Common "Warnings" & How to Read Them

### "Discovered Python interpreter" Warning
> `[WARNING]: Platform linux on host ... is using the discovered Python interpreter at /usr/bin/python3.10...`
- **Meaning**: Ansible found Python automatically. It’s letting you know that if you install multiple versions of Python later, it might get confused.
- **Fix**: Safe to ignore for this project.

### "Skipping" Tasks
> `TASK [geerlingguy.docker : include_tasks] skipping: [51.20.185.59]`
- **Meaning**: The Docker role is cross-platform. It’s skipping RedHat/CentOS tasks because it detected you are on Ubuntu.
- **Fix**: No action needed; this is standard Ansible behavior.

### "Changed" vs "OK"
- **OK**: The system was already in the desired state (e.g., Git was already installed).
- **Changed**: Ansible had to take action (e.g., it turned off a service that was running).
