#!/bin/bash
# ==============================================================================
# SETUP-WORKER.SH — Universal Worker Installer (VM 2, VM 3, VM 4, dst)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Penggunaan:
#   ./setup-worker.sh <WORKER_ID> "<TOKEN_KUNCI_INDUK>" [HOST_VM1]
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

WORKER_ID="${1:-}"
TOKEN="${2:-}"
VM1_HOST="${3:-ssh.ourme.my.id}"
LOCAL_PORT="${4:-20129}"

echo -e "\n${CYAN}======================================================================${NC}"
echo -e "${CYAN}    🌐 MUSE MULTI-VM MESH TUNNEL: SETUP WORKER NODE                    ${NC}"
echo -e "${CYAN}======================================================================${NC}\n"

# 1. Validasi Input
if [ -z "$WORKER_ID" ]; then
    echo -e "${YELLOW}Masukkan Nomor ID Worker (contoh: 2 untuk VM 2, 3 untuk VM 3):${NC}"
    read -r WORKER_ID
fi

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}Tempelkan Token Kunci Induk (yang didapat dari setup-hub.sh):${NC}"
    read -r TOKEN
fi

if [ -z "$WORKER_ID" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: Nomor Worker ID dan Token Kunci Induk wajib diisi!${NC}" >&2
    exit 1
fi

REMOTE_PORT=$(( 20128 + WORKER_ID ))
SSH_USER="root"
SSH_KEY_HATCH="/home/hatch/.ssh/id_mesh_master"
SSH_KEY_ROOT="/root/.ssh/id_mesh_master"
SERVICE_NAME="reverse-tunnel-worker${WORKER_ID}"
HOST_ALIAS="vm1-hub-w${WORKER_ID}"

echo -e "Node ID           : ${GREEN}VM ${WORKER_ID}${NC}"
echo -e "Port Internal     : ${GREEN}${LOCAL_PORT}${NC} (Muse Bridge)"
echo -e "Port Remote VM 1  : ${YELLOW}${REMOTE_PORT}${NC} (Endpoint di 9Router)"
echo -e "Hub VM 1          : ${GREEN}${VM1_HOST}${NC}"
echo -e "Systemd Service   : ${GREEN}${SERVICE_NAME}.service${NC}"
echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"

# 2. Pastikan folder .ssh ada untuk hatch dan root
mkdir -p /home/hatch/.ssh /root/.ssh
chmod 700 /home/hatch/.ssh /root/.ssh

# 3. Pasang Kunci Induk dari Token ke hatch dan root
echo -e "${YELLOW}[1/4] Memasang Kunci Induk dari Token...${NC}"
echo "$TOKEN" | base64 -d > "$SSH_KEY_HATCH"
chmod 600 "$SSH_KEY_HATCH"
cp -p "$SSH_KEY_HATCH" "$SSH_KEY_ROOT" 2>/dev/null || true
chmod 600 "$SSH_KEY_ROOT" 2>/dev/null || true
echo -e "${GREEN}✓ Kunci terpasang di ${SSH_KEY_HATCH} dan ${SSH_KEY_ROOT}.${NC}"

# 4. Konfigurasi SSH Client (~/.ssh/config) untuk hatch dan root
echo -e "${YELLOW}[2/4] Mengonfigurasi Cloudflare SSH Access...${NC}"
SSH_BLOCK="
# ---- Muse Mesh Tunnel: Hub VM 1 (Worker ${WORKER_ID}) ----
Host ${HOST_ALIAS}
    HostName ${VM1_HOST}
    User ${SSH_USER}
    IdentityFile ${SSH_KEY_HATCH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
"

if ! grep -q "Host ${HOST_ALIAS}" /home/hatch/.ssh/config 2>/dev/null; then
    echo "$SSH_BLOCK" >> /home/hatch/.ssh/config
    chmod 600 /home/hatch/.ssh/config
fi

if ! grep -q "Host ${HOST_ALIAS}" /root/.ssh/config 2>/dev/null; then
    echo "$SSH_BLOCK" >> /root/.ssh/config
    chmod 600 /root/.ssh/config
fi
echo -e "${GREEN}✓ Konfigurasi alias '${HOST_ALIAS}' berhasil ditambahkan.${NC}"

# 5. Pasang dan Aktifkan systemd service (eksplisit dengan config dan identity file)
echo -e "${YELLOW}[3/4] Memasang service auto-reconnect ${SERVICE_NAME}.service...${NC}"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=SSH Reverse Tunnel Worker VM ${WORKER_ID} ke 9Router VM 1 (Port ${REMOTE_PORT})
After=network.target muse-bridge.service
Wants=muse-bridge.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -F /home/hatch/.ssh/config -i ${SSH_KEY_HATCH} -N -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} ${HOST_ALIAS}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"
echo -e "${GREEN}✓ Service ${SERVICE_NAME}.service aktif & berjalan!${NC}"

# 6. Pasang ke recover.sh (Anti-VM Replace)
RECOVER_SH="/home/hatch/workspace/vm-recovery/recover.sh"
if [ -f "$RECOVER_SH" ]; then
    echo -e "${YELLOW}[4/4] Mengamankan konfigurasi ke $RECOVER_SH...${NC}"
    if ! grep -q "${SERVICE_NAME}" "$RECOVER_SH"; then
        cat >> "$RECOVER_SH" << EOF

# ---- Muse Multi-VM Reverse Tunnel Worker ${WORKER_ID} ----
if [ ! -f /etc/systemd/system/${SERVICE_NAME}.service ]; then
  cat > /etc/systemd/system/${SERVICE_NAME}.service << 'UNIT'
[Unit]
Description=SSH Reverse Tunnel Worker VM ${WORKER_ID} ke 9Router VM 1 (Port ${REMOTE_PORT})
After=network.target muse-bridge.service
Wants=muse-bridge.service
[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -F /home/hatch/.ssh/config -i /home/hatch/.ssh/id_mesh_master -N -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} ${HOST_ALIAS}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now ${SERVICE_NAME}.service
fi
EOF
        echo -e "${GREEN}✓ Berhasil diamankan di recover.sh.${NC}"
    else
        echo -e "${GREEN}✓ Sudah terdaftar di recover.sh.${NC}"
    fi
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 SUKSES! WORKER VM ${WORKER_ID} TELAH TERHUBUNG KE VM 1!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "\nTunnel aktif menghubungkan Muse Bridge worker ini ke VM 1:"
echo -e "👉 ${YELLOW}http://127.0.0.1:${REMOTE_PORT}/v1${NC}\n"

echo -e "${CYAN}Konfigurasi Provider di 9Router (VM 1):${NC}"
echo -e "- Provider Name : ${YELLOW}Muse-VM${WORKER_ID}${NC}"
echo -e "- Base URL      : ${YELLOW}http://127.0.0.1:${REMOTE_PORT}/v1${NC}"
echo -e "- Model ID      : ${YELLOW}muse/muse-spark-vm${WORKER_ID}${NC}\n"
echo -e "${GREEN}======================================================================${NC}\n"
