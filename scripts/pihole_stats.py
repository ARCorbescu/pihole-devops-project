import os
import time
from pihole6api import PiHole6Client

# Citim din variabile de mediu sau folosim valori default
host = os.getenv("PIHOLE_URL", "http://localhost")
token = os.getenv("PIHOLE_API_KEY", "MyPass123")

print(f"🔗 Connecting to Pi-hole at {host}")

client = PiHole6Client(host, token)

while True:
    try:
        history = client.metrics.get_history()
        print(f"[OK] History: {history}")
        queries = client.metrics.get_queries()
        print(f"[OK] Queries: {queries}")
    except Exception as e:
        print(f"[!] Error: {e}")

    time.sleep(30)
