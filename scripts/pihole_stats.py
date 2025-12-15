"""
Pi-hole Stats & Control Script

This script does two main things:
1. Runs a background thread to periodically poll Pi-hole for statistics (history, queries) 
   and prints them to the console.
2. Starts a Flask web server that listens for specific webhooks (e.g., from Siri Shortcuts)
   to block or unblock specific domains (like social media sites) on the Pi-hole.

Dependencies:
- flask: For the web server.
- pihole6api: A Python wrapper for the Pi-hole v6 API.
"""

import os
import time
import threading
from flask import Flask, request
from pihole6api import PiHole6Client

# -----------------------------------------------------
# Pi-hole setup
# -----------------------------------------------------

# Load configuration from environment variables.
# PIHOLE_URL: The base URL of your Pi-hole instance
# PIHOLE_API_KEY: The API token/password for authentication
host = os.getenv("PIHOLE_URL", "Something went wrong with the URL")
token = os.getenv("PIHOLE_API_KEY", "Something went wrong with the password")

print(f"🔗 Connecting to Pi-hole at {host}")

# Initialize the Pi-hole client with the provided credentials.
client = PiHole6Client(host, token)

# Domains you want Siri to block/unblock.
# These are the sites that will be added/removed from the blocklist.
DOMAINS_TO_BLOCK = [
    r"(\.|^)netflix\.com$",
    r"(\.|^)instagram\.com$",
    r"(\.|^)tiktok\.com$",
    r".*amkai.*",
    r".*akami.*",
    r".*tiktok.*",
    r".*appsflyer.*"

]

# -----------------------------------------------------
# Background thread: poll Pi-hole metrics
# -----------------------------------------------------

def poll_pihole():
    """
    Periodically polls Pi-hole for usage statistics.

    This function runs in a separate thread. It fetches:
    - History: Historical data of queries.
    - Queries: Recent DNS queries.

    It prints the results to the console for monitoring purposes.
    """
    # Wait 35 seconds initially to allow the system/network to fully start up.
    time.sleep(35)
    while True:
        try:
            # Fetch and print historical statistics
            history = client.metrics.get_history()
            print(f"[OK] History: {history}")
            # Fetch and print recent queries
            queries = client.metrics.get_queries()
            print(f"[OK] Queries: {queries}")
        except Exception as e:
            # Catch and log any errors during polling so the thread doesn't crash
            print(f"[!] Error polling Pi-hole: {e}")
        # Wait for 30 seconds before the next poll
        time.sleep(30)

# Start the polling function in a daemon thread.
# Daemon threads automatically exit when the main program exits.
threading.Thread(target=poll_pihole, daemon=True).start()

# -----------------------------------------------------
# Flask API for Siri webhooks
# -----------------------------------------------------

app = Flask(__name__)

@app.route('/break_the_internet', methods=['GET','POST'])
def break_the_internet():
    """
    Webhook to block specific domains.

    Triggered via GET or POST request to /break_the_internet.
    Iterates through DOMAINS_TO_BLOCK and adds them to the Pi-hole's deny list.

    Returns:
        tuple: A success message and HTTP 200 status, or an error message and HTTP 500.
    """
    print("💥 Siri: BREAK THE INTERNET!")

    try:
        for domain in DOMAINS_TO_BLOCK:
            print(f"Blocking: {domain}")
            # Add the domain to the 'deny' list (blacklist) with 'regex' matching.
            # This prevents access to these sites immediately.
            client.domain_management.add_domain(domain, "deny", "regex", groups=[0])
        return "Internet broken 😈", 200

    except Exception as e:
        print(f"[!] Error blocking: {e}")
        return f"Error: {e}", 500


@app.route('/fix_the_internet', methods=['GET','POST'])
def fix_the_internet():
    """
    Webhook to unblock specific domains.

    Triggered via GET or POST request to /fix_the_internet.
    Iterates through DOMAINS_TO_BLOCK and removes them from the Pi-hole's deny list.

    Returns:
        tuple: A success message and HTTP 200 status, or an error message and HTTP 500.
    """
    print("🛠️ Siri: FIX THE INTERNET!")

    try:
        for domain in DOMAINS_TO_BLOCK:
            print(f"Unblocking: {domain}")
            # Remove the domain from the 'deny' list.
            # This restores access to these sites.
            client.domain_management.delete_domain(domain, "deny", "regex")
        return "Internet fixed 😇", 200

    except Exception as e:
        print(f"[!] Error unblocking: {e}")
        return f"Error: {e}", 500

@app.route('/block_dns', methods=['GET','POST'])
def block_dns():
    """
    Webhook to enable Pi-hole's DNS blocking.

    Triggered via GET or POST request to /block_dns.
    Enables Pi-hole's blocking feature, which filters DNS queries based on configured blocklists.

    Query Parameters:
        timer (int, optional): Duration in seconds for temporary blocking. 
                               If not provided, blocking is enabled permanently.
                               Example: /block_dns?timer=300 (enable for 5 minutes)

    Returns:
        tuple: A success message and HTTP 200 status, or an error message and HTTP 500.
    """
    print("🚫 Enabling Pi-hole DNS blocking...")
    
    # Get optional timer parameter from query string
    timer = request.args.get('timer', type=int)
    
    try:
        result = client.dns_control.set_blocking_status(True, timer)
        message = f"Pi-hole blocking enabled {'permanently' if timer is None else f'for {timer} seconds'} ✅"
        print(f"[OK] {message}")
        return message, 200
    except Exception as e:
        print(f"[!] Error enabling blocking: {e}")
        return f"Error: {e}", 500


@app.route('/unblock_dns', methods=['GET','POST'])
def unblock_dns():
    """
    Webhook to disable Pi-hole's DNS blocking.

    Triggered via GET or POST request to /unblock_dns.
    Disables Pi-hole's blocking feature, allowing all DNS queries to pass through unfiltered.

    Query Parameters:
        timer (int, optional): Duration in seconds for temporary unblocking. 
                               If not provided, blocking is disabled permanently.
                               Example: /unblock_dns?timer=600 (disable for 10 minutes)

    Returns:
        tuple: A success message and HTTP 200 status, or an error message and HTTP 500.
    """
    print("✅ Disabling Pi-hole DNS blocking...")
    
    # Get optional timer parameter from query string
    timer = request.args.get('timer', type=int)
    
    try:
        result = client.dns_control.set_blocking_status(False, timer)
        message = f"Pi-hole blocking disabled {'permanently' if timer is None else f'for {timer} seconds'} 🔓"
        print(f"[OK] {message}")
        return message, 200
    except Exception as e:
        print(f"[!] Error disabling blocking: {e}")
        return f"Error: {e}", 500


if __name__ == "__main__":
    # Run the Flask app on all available network interfaces (0.0.0.0) on port 5005.
    app.run(host="0.0.0.0", port=5005)
