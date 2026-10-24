# 🔒 Tailscale Mesh DNS Setup Guide

This guide explains how to use your local Pi-hole container as a private, secure DNS server for yourself and your friends across your city using **Tailscale**.

---

## 🌟 Why Tailscale for Pi-hole?

Traditional port forwarding for DNS (UDP port 53) on your home router is **extremely dangerous**:
* **Open DNS Resolver Risk**: Anyone on the internet can scan and discover your port 53, using your machine to launch **DNS Amplification DDoS attacks**. This can get your home IP blacklisted and your ISP service suspended.
* **ISP Restrictions**: Most residential ISPs block inbound port 53 and place home connections behind **CGNAT** (Carrier Grade NAT).

**Tailscale solves this completely:**
* ✅ **Zero open ports** on your home router.
* ✅ **End-to-End Encrypted** peer-to-peer WireGuard tunnels.
* ✅ **Works through CGNAT & Dynamic IPs** without DDNS or port forwarding.
* ✅ **Works everywhere**: Friends get ad-blocking at home, in cafes, and on mobile data (4G/5G).

---

## 🚀 Quick Setup (Under 10 Minutes)

### Phase 1: Launch Pi-hole Locally

1. **Navigate to the `docker/` directory**:
   ```bash
   cd docker
   ```

2. **Create your environment configuration**:
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env`** to set a secure password:
   ```env
   PIHOLE_PASSWORD=MySecurePassword123!
   ```

4. **Start the containers**:
   ```bash
   docker compose up -d
   ```

5. **Verify it is running**:
   * Open your browser: [http://localhost/admin](http://localhost/admin)
   * Log in with the password you set in `.env`.
   * Test local resolution:
     ```bash
     dig @127.0.0.1 flurry.com
     # Should return 0.0.0.0 (blocked by Pi-hole default lists)
     ```

---

### Phase 2: Set Up Tailscale on Your Host (Recommended)

Running Tailscale natively on your host machine (Mac or Linux) is the simplest and most performant approach because Docker already maps port `53:53` to your host interface.

1. **Install Tailscale**:
   * **macOS**: Download from the [Mac App Store](https://apps.apple.com/app/tailscale/id1475387142) or install via Homebrew:
     ```bash
     brew install --cask tailscale
     ```
   * **Linux**:
     ```bash
     curl -fsSL https://tailscale.com/install.sh | sh
     sudo tailscale up
     ```

2. **Log In**:
   * Open Tailscale and sign in (free personal account with Google, Apple, or GitHub).

3. **Get Your Tailscale IP Address**:
   * Click the Tailscale icon in your macOS menu bar, or in terminal run:
     ```bash
     tailscale ip -4
     ```
   * You will receive an IP starting with `100.x.y.z` (e.g., `100.85.120.45`).
   * *Because Pi-hole binds to `0.0.0.0:53`, it is already listening on this Tailscale IP!*

---

### Phase 3: Share Your Pi-hole with Friends

Tailscale includes a built-in feature called **Node Sharing** that allows you to securely share an individual machine with friends without sharing your entire account or other personal devices.

#### 1. Generate a Share Invite
1. Log into your [Tailscale Admin Console](https://login.tailscale.com/admin/machines).
2. Locate the device running your Pi-hole (e.g. your Mac).
3. Click the **`...`** (options) button on the right side of the row.
4. Select **Share...**.
5. Copy the generated invite link.

#### 2. Have Your Friend Accept the Invite
1. Send the invite link to your friend.
2. When your friend opens the link, they log in with their own free Tailscale account.
3. Your machine now appears in your friend's Tailscale device list with its dedicated `100.x.y.z` IP address!

---

### Phase 4: Configure DNS on Your Friend's Device

Once connected to Tailscale, your friend can point their DNS to your Pi-hole's `100.x.y.z` IP:

#### On macOS / Windows:
1. Open Network Settings (Wi-Fi or Ethernet adapter properties).
2. Under DNS Servers, set the primary DNS to your Pi-hole's Tailscale IP (`100.x.y.z`).
3. Set a fallback DNS (e.g. `1.1.1.1`).

#### In Web Browsers (Chrome / Brave / Firefox):
If they only want ad-blocking in their browser:
1. Open Browser Settings → **Privacy & Security** → **Security**.
2. Under **Use secure DNS**, select **Custom**.
3. (Optional: Use DNS-over-HTTPS if configured, or device-level DNS).

#### For Devices Owned by You:
In your [Tailscale DNS Console](https://login.tailscale.com/admin/dns):
1. Click **Add Nameserver** → **Custom**.
2. Enter your Pi-hole's `100.x.y.z` address.
3. Enable **Override local DNS** (MagicDNS).
4. All your connected phones, tablets, and laptops will automatically use Pi-hole with zero manual configuration!

---

## 🧪 Testing & Verification

1. **Verify ad-blocking from a friend's machine**:
   ```bash
   nslookup flurry.com <YOUR_TAILSCALE_IP>
   ```
   Output should be `0.0.0.0`.

2. **Check the Pi-hole Dashboard**:
   * Open `http://localhost/admin` (or `http://<YOUR_TAILSCALE_IP>/admin`).
   * Go to **Query Log**.
   * You will see incoming queries from your friend's Tailscale IP address in real time!

---

## 🛠️ Alternative: Running Tailscale Directly in Docker

If you prefer to run Tailscale in a headless container rather than installing the desktop app:

1. Generate an auth key from [Tailscale Admin Console → Keys](https://login.tailscale.com/admin/settings/keys).
2. Add your auth key to `docker/.env`:
   ```env
   TS_AUTHKEY=tskey-auth-xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx
   ```
3. Start the stack with the `tailscale` profile:
   ```bash
   docker compose --profile tailscale up -d
   ```
4. View the Tailscale IP:
   ```bash
   docker exec -it tailscale tailscale ip -4
   ```
