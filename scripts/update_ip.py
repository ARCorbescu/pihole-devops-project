import time
import urllib.request
import subprocess
import json

SG_NAME = "allow_ssh"
# Ports to monitor: 22(SSH), 80(HTTP), 5005(Webhook), 53(DNS - TCP/UDP)
PORTS_CONFIG = {
    22: ["tcp"],
    80: ["tcp"],
    5005: ["tcp"],
    53: ["tcp", "udp"]
}
CHECK_INTERVAL = 12 * 3600  # 12 hours

def get_public_ip():
    """Get current public IP from Amazon."""
    return urllib.request.urlopen('https://checkip.amazonaws.com').read().decode('utf8').strip()

def get_sg_id():
    """Get Security Group ID."""
    return subprocess.check_output([
        "aws", "ec2", "describe-security-groups", 
        "--filters", f"Name=group-name,Values={SG_NAME}", 
        "--query", "SecurityGroups[0].GroupId", 
        "--output", "text"
    ]).decode().strip()

def update_security_group(sg_id, current_ip):
    """Revoke old IPs and authorize new IP."""
    print(f"🔄 verifying rules for {current_ip}...")

    # 1. Get current rules
    raw_rules = subprocess.check_output(["aws", "ec2", "describe-security-groups", "--group-ids", sg_id, "--output", "json"])
    rules = json.loads(raw_rules)['SecurityGroups'][0]['IpPermissions']

    # 2. Revoke Mismatches
    for rule in rules:
        port = rule.get('FromPort')
        proto = rule.get('IpProtocol')

        # Only touch ports we care about
        if port in PORTS_CONFIG and proto in PORTS_CONFIG[port]:
            for ip_range in rule.get('IpRanges', []):
                cidr = ip_range.get('CidrIp')
                # If IP matches our current one OR is global (0.0.0.0/0), keep it.
                # Otherwise, it's an old dynamic IP -> Kill it.
                if cidr != f"{current_ip}/32" and cidr != "0.0.0.0/0":
                    print(f"[-] Revoking old rule: {proto}:{port} for {cidr}")
                    subprocess.run([
                        "aws", "ec2", "revoke-security-group-ingress",
                        "--group-id", sg_id,
                        "--protocol", proto,
                        "--port", str(port),
                        "--cidr", cidr
                    ], check=True)

    # 3. Authorize Missing
    for port, protocols in PORTS_CONFIG.items():
        for proto in protocols:
            # We use 'run' without check=True to ignore "Duplicate" errors if rule exists
            # We redirect stderr to suppress "InvalidPermission.Duplicate" noise
            subprocess.run([
                "aws", "ec2", "authorize-security-group-ingress",
                "--group-id", sg_id,
                "--protocol", proto,
                "--port", str(port),
                "--cidr", f"{current_ip}/32"
            ], stderr=subprocess.DEVNULL)

def main():
    print("🚀 IP Monitor Started (Interval: 12h)")
    # Wrap getting SG_ID in try/except in case of network blip on start
    try:
        sg_id = get_sg_id()
    except Exception as e:
        print(f"Fatal Error getting Security Group: {e}")
        return

    while True:
        try:
            current_ip = get_public_ip()
            print(f"\n⏰ Time: {time.ctime()} | IP: {current_ip}")
            update_security_group(sg_id, current_ip)
        except Exception as e:
            print(f"💥 Error causing monitor cycle to fail: {e}")

        print("💤 Sleeping...")
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
