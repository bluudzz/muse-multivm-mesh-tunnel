#!/bin/bash
# ==============================================================================
# QUICK-CONNECT.SH — 1-Click Zero-Touch Installer Worker (VM 2, VM 3, VM 4, dst)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Penggunaan:
#   ./quick-connect.sh <WORKER_ID> "<MASTER_KEY_BASE64>" [VM1_HOST]
# Contoh untuk VM 2:
#   ./quick-connect.sh 2 "LS0t...=="
# Contoh untuk VM 3:
#   ./quick-connect.sh 3 "LS0t...=="
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

WORKER_ID="${1:-2}"
MASTER_KEY_B64="${2:-}"
VM1_HOST="${3:-ssh.ourme.my.id}"
LOCAL_PORT="${4:-20129}"

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}  MUSE MESH TUNNEL: QUICK CONNECT (ZERO-TOUCH)        ${NC}"
echo -e "${CYAN}======================================================${NC}"

if [ -z "$MASTER_KEY_B64" ]; then
    echo -e "${RED}Error: Kunci Induk (Master Key Base64) wajib disertakan!${NC}"
    echo -e "Format: $0 <WORKER_ID> \"<MASTER_KEY_BASE64>\""
    exit 1
fi

REMOTE_PORT=$(( 20128 + WORKER_ID ))
SSH_USER="root"
SSH_KEY="/home/hatch/.ssh/id_mesh_master"
SERVICE_NAME="reverse-tunnel-worker${WORKER_ID}"
HOST_ALIAS="vm1-hub-w${WORKER_ID}"

echo -e "Worker ID         : ${GREEN}VM ${WORKER_ID}${NC}"
echo -e "Port Lokal        : ${GREEN}${LOCAL_PORT}${NC}"
echo -e "Port Remote VM 1  : ${YELLOW}${REMOTE_PORT}${NC}"
echo -e "Host VM 1 (Hub)   : ${GREEN}${VM1_HOST}${NC}"
echo -e "${CYAN}------------------------------------------------------${NC}\n"

# 1. Pastikan folder .ssh ada
mkdir -p /home/hatch/.ssh
chmod 700 /home/hatch/.ssh

# 2. Pasang Kunci Induk
echo -e "${YELLOW}[1/4] Menginstal Kunci Induk (Master Mesh Key)...${NC}"
echo "$MASTER_KEY_B64" | base64 -d > "$SSH_KEY"
chmod 600 "$SSH_KEY"
echo -e "${GREEN}✓ Kunci Induk berhasil dipasang di $SSH_KEY.${NC}"

# 3. Konfigurasi ~/.ssh/config dengan Cloudflared
echo -e "${YELLOW}[2/4] Mengonfigurasi Cloudflare SSH Access...${NC}"
if ! grep -q "Host ${HOST_ALIAS}" /home/hatch/.ssh/config 2>/dev/null; then
    cat >> /home/hatch/.ssh/config << EOF

# ---- Muse Mesh Tunnel: Hub VM 1 (Worker ${WORKER_ID}) ----
Host ${HOST_ALIAS}
    HostName ${VM1_HOST}
    User ${SSH_USER}
    IdentityFile ${SSH_KEY}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
EOF
    chmod 600 /home/hatch/.ssh/config
    echo -e "${GREEN}✓ Alias SSH '${HOST_ALIAS}' berhasil dikonfigurasi.${NC}"
else
    echo -e "${GREEN}✓ Alias '${HOST_ALIAS}' sudah ada di ~/.ssh/config.${NC}"
fi

# 4. Pasang systemd service reverse tunnel
echo -e "${YELLOW}[3/4] Mengaktifkan service systemd ${SERVICE_NAME}.service...${NC}"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=SSH Reverse Tunnel Worker VM ${WORKER_ID} ke 9Router VM 1 (Port ${REMOTE_PORT})
After=network.target muse-bridge.service
Wants=muse-bridge.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -N -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} ${HOST_ALIAS}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"
echo -e "${GREEN}✓ Service tunnel aktif & berjalan!${NC}"

# 5. Pasang ke recover.sh (Anti-VM Replace)
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
ExecStart=/usr/bin/ssh -N -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} ${HOST_ALIAS}
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
        echo -e "${GREEN}✓ Konfigurasi sudah ada di recover.sh.${NC}"
    fi
fi

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}🎉 SUKSES! WORKER VM ${WORKER_ID} TELAH TERHUBUNG KE VM 1!${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "Tunnel langsung aktif membawa Muse Bridge worker ini ke:"
echo -e "👉 ${YELLOW}http://127.0.0.1:${REMOTE_PORT}/v1${NC} di VM 1."
echo -e "\n${GREEN}Anda TIDAK PERLU melakukan setting apa-apa lagi di VM 1!${NC}\n"
