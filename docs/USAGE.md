# Usage Guide

## 1. Web Interface
Access the Pi-hole dashboard to view stats and manage blocklists.
- **URL**: `http://<YOUR_EC2_IP>/admin`
- **Password**: The one you set in `ansible/vault.yml` (Default: `PiAdmin`).

## 2. Dynamic IP Automation
If your home IP changes, you will lose access to the server (SSH/HTTP).
Use the included script to automatically update the AWS Security Group rules.

```bash
# Run once to check/update
python3 scripts/update_ip.py

# Run in background (checks every 12 hours)
nohup python3 scripts/update_ip.py &
```

## 3. Webhook (Siri Shortcuts)
Control the Pi-hole blocking via HTTP requests (e.g., from Shortcuts, Scriptable, or Curl).

| Action | Method | URL |
| :--- | :--- | :--- |
| **Block Social** | `GET/POST` | `http://<EC2_IP>:5005/break_the_internet` |
| **Unblock Social** | `GET/POST` | `http://<EC2_IP>:5005/fix_the_internet` |
| **Test Status** | `GET/POST` | `http://<EC2_IP>:5005/trigger` |

*Note: The webhook is secured by the AWS Security Group (your IP only).* 
