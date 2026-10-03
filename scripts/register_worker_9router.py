#!/usr/bin/env python3
# ==============================================================================
# REGISTER_WORKER_9ROUTER.PY — Registrasi Otomatis Worker ke 9Router
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
import sys
import sqlite3
import json
import datetime
import subprocess

if len(sys.argv) < 3:
    print("Usage: register_worker_9router.py <WORKER_ID> <PORT>")
    sys.exit(1)

worker_id = sys.argv[1]
port = sys.argv[2]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()

node_id = f"openai-compatible-chat-muse-vm{worker_id}"
node_name = f"Muse VM{worker_id}"
prefix = f"vm{worker_id}"
base_url = f"http://127.0.0.1:{port}/v1"

node_data = {
    "prefix": prefix,
    "apiType": "chat",
    "baseUrl": base_url
}

conn_id = f"conn-muse-vm{worker_id}"
conn_data = {
    "apiKey": "e58aed37c658ed6a0793ac5a1b2920ad12b281f13993fa577d7b724a81761f60",
    "testStatus": "active",
    "providerSpecificData": {
        "prefix": prefix,
        "apiType": "chat",
        "baseUrl": base_url,
        "nodeName": node_name,
        "connectionProxyEnabled": False,
        "connectionProxyUrl": "",
        "connectionNoProxy": ""
    }
}

db_path = "/home/hatch/.9router/db/data.sqlite"
db = sqlite3.connect(db_path)
cur = db.cursor()

# 1. Insert or update providerNodes
cur.execute("""
INSERT INTO providerNodes (id, type, name, data, createdAt, updatedAt)
VALUES (?, 'openai-compatible', ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
    name=excluded.name,
    data=excluded.data,
    updatedAt=excluded.updatedAt
""", (node_id, node_name, json.dumps(node_data), now, now))

# 2. Insert or update providerConnections
cur.execute("""
INSERT INTO providerConnections (id, provider, authType, name, email, priority, isActive, data, createdAt, updatedAt)
VALUES (?, ?, 'apikey', ?, NULL, 1, 1, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
    data=excluded.data,
    isActive=1,
    updatedAt=excluded.updatedAt
""", (conn_id, node_id, f"{node_name} Key", json.dumps(conn_data), now, now))

db.commit()
db.close()
print(f"9ROUTER_REGISTER_SUCCESS: {node_name} at {base_url}")

# Restart 9router to reload configuration
try:
    subprocess.run(["systemctl", "restart", "9router"], check=True)
    print("9ROUTER_RESTART_SUCCESS")
except Exception as e:
    print(f"9ROUTER_RESTART_NOTE: {e}")
