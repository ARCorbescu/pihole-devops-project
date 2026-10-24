# Pi-hole DevOps Project

**Local Pi-hole DNS Server + Tailscale Mesh VPN for Friends**

Run a containerised Pi-hole ad-blocker on your local machine and securely share it with friends across the city via Tailscale — zero port forwarding, zero open resolvers, fully encrypted.

---

## 📋 Table of Contents
- [Quick Start](#-quick-start)
- [Tailscale Setup](#-tailscale-setup)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Maintenance](#-maintenance)
- [Security](#-security)

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/ARCorbescu/pihole-devops-project.git
cd pihole-devops-project

# 2. Configure environment
cd docker
cp .env.example .env
# Edit .env and set PIHOLE_PASSWORD

# 3. Start Pi-hole
docker compose up -d
```

**Verify it works:**
- Web Admin: [http://localhost/admin](http://localhost/admin)
- DNS test: `dig @127.0.0.1 flurry.com` → should return `0.0.0.0` (blocked)

---

## 🔗 Tailscale Setup

### Step 1: Connect via Tailscale

#### Option A: Native Tailscale App on your Mac (Easiest & Recommended)

1. Install Tailscale on your Mac via [Tailscale.com](https://tailscale.com/) or Homebrew:
   ```bash
   brew install --cask tailscale
   ```
2. Open Tailscale and log in (free personal account).
3. Note your machine's Tailscale IP:
   ```bash
   tailscale ip -4
   # e.g. 100.85.x.y
   ```
4. Because Docker exposes port 53 to your host, **Pi-hole is already accessible over that Tailscale IP!**

#### Option B: Containerised Tailscale

1. Generate an auth key from [Tailscale Admin Console → Settings → Keys](https://login.tailscale.com/admin/settings/keys).
2. Set `TS_AUTHKEY=tskey-auth-...` in `docker/.env`.
3. Start the stack with the Tailscale profile:
   ```bash
   docker compose --profile tailscale up -d
   ```

### Step 2: Share with Friends (Tailscale Node Sharing)

1. Open your [Tailscale Machines Console](https://login.tailscale.com/admin/machines).
2. Find your Pi-hole machine, click the **`…`** menu on the right, and click **Share…**.
3. Copy the invite link and send it to your friend.
4. Once your friend accepts and connects their Tailscale app, they set their device's DNS server to your Pi-hole's `100.x.y.z` IP.

> All traffic stays encrypted over WireGuard, with **zero router ports opened**.

For the full Tailscale walkthrough (including friend device DNS configuration), see [docs/TAILSCALE_SETUP.md](docs/TAILSCALE_SETUP.md).

---

## 📁 Project Structure

```
pihole-devops-project/
├── docker/                           # Docker Compose configuration
│   ├── docker-compose.yml            # Pi-hole + Bash Monitor + Tailscale
│   ├── .env.example                  # Environment variable template
│   └── Dockerfile.monitor-bash       # System resource monitor image
│
├── scripts/                          # Utility scripts
│   └── system_monitor.sh             # Bash system monitor (CPU, RAM, Disk)
│
├── docs/                             # Documentation
│   ├── TAILSCALE_SETUP.md            # Full Tailscale + Friends guide
│   ├── ARCHITECTURE.md               # Technical architecture deep-dive
│   ├── INSTALLATION.md               # Installation walkthrough (AWS legacy)
│   ├── USAGE.md                      # Usage guide
│   └── cheat_sheet.md                # Quick command reference
│
├── terraform/                        # AWS infrastructure (legacy/cloud branch)
├── ansible/                          # Ansible config management (legacy/cloud branch)
└── .env.example                      # Root environment template
```

---

## ✅ Prerequisites

- **Docker Desktop** (macOS / Windows) or **Docker Engine** (Linux)
- **Tailscale** — free account at [tailscale.com](https://tailscale.com)
- Port 53 available on your host (check with `lsof -i :53`)

---

## 🛠️ Maintenance

### Update Pi-hole
```bash
cd docker
docker compose pull pihole
docker compose up -d
```

### View Logs
```bash
docker compose logs -f pihole
```

### Restart Pi-hole
```bash
docker compose restart pihole
```

### Stop Everything
```bash
docker compose down
```

---

## 🔒 Security

- **Tailscale Mesh VPN**: All DNS queries between friends and your Pi-hole travel over encrypted WireGuard tunnels.
- **No Open Ports**: Pi-hole's DNS port (53) is never exposed to the public internet.
- **Environment Secrets**: Passwords stored in `.env` (git-ignored).
- **Minimal Attack Surface**: Only ports 53 and 80 bound to localhost/Tailscale.

---

## 📖 Learning Resources

This project demonstrates:
- **Containerisation** (Docker, Docker Compose)
- **DNS Management** (Pi-hole v6, ad-blocking)
- **Mesh VPN Networking** (Tailscale, WireGuard)
- **System Monitoring** (Bash scripting)

---

**Author**: ARCorbescu
**Repository**: https://github.com/ARCorbescu/pihole-devops-project
