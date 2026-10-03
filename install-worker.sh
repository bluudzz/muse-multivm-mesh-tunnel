#!/bin/bash
# ==============================================================================
# INSTALL-WORKER.SH — Universal Worker Installer untuk Muse Spark VMs (Hatch)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Penggunaan:
#   ./install-worker.sh [WORKER_ID] [VM1_HOST] [LOCAL_PORT]
# Contoh:
#   ./install-worker.sh 2    -> Port Remote di VM 1: 20130
#   ./install-worker.sh 3    -> Port Remote di VM 1: 20131
#   ./install-worker.sh 4    -> Port Remote di VM 1: 20132
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

WORKER_ID="${1:-2}"
VM1_HOST="${2:-ssh.yourdomain.com}"
LOCAL_PORT="${3:-20129}"

# Hitung port remote: VM 2 -> 20130, VM 3 -> 20131, dst.
REMOTE_PORT=$(( 20128 + WORKER_ID ))

SSH_USER="root"
SSH_KEY="/home/hatch/.ssh/id_worker${WORKER_ID}"
SERVICE_NAME="reverse-tunnel-worker${WORKER_ID}"

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}  MUSE MESH TUNNEL: INSTALLER WORKER VM ${WORKER_ID}           ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "Node ID           : ${GREEN}VM ${WORKER_ID}${NC}"
echo -e "Local Port        : ${GREEN}${LOCAL_PORT}${NC} (Muse Bridge lokal)"
echo -e "Remote Port VM 1  : ${YELLOW}${REMOTE_PORT}${NC} (Port forward di VM 1)"
echo -e "VM 1 Host (SSH)   : ${GREEN}${VM1_HOST}${NC}"
echo -e "Systemd Service   : ${GREEN}${SERVICE_NAME}.service${NC}"
echo -e "${CYAN}------------------------------------------------------${NC}\n"

# 1. Pastikan direktori .ssh ada
mkdir -p /home/hatch/.ssh
chmod 700 /home/hatch/.ssh

# 2. Buat SSH key khusus worker ini jika belum ada
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${YELLOW}[1/5] Membuat SSH Key ed25519 baru (${SSH_KEY})...${NC}"
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY" -C "worker-vm${WORKER_ID}@hatch"
    chmod 600 "$SSH_KEY"
    chmod 644 "${SSH_KEY}.pub"
else
    echo -e "${GREEN}[1/5] SSH Key sudah ada: ${SSH_KEY}${NC}"
fi

# 3. Konfigurasi SSH Config dengan Cloudflare Access
echo -e "${YELLOW}[2/5] Mengonfigurasi /home/hatch/.ssh/config...${NC}"
HOST_ALIAS="vm1-hub-w${WORKER_ID}"

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
    echo -e "${GREEN}✓ Konfigurasi SSH alias '${HOST_ALIAS}' berhasil ditambahkan.${NC}"
else
    echo -e "${GREEN}✓ Entry '${HOST_ALIAS}' sudah ada di ~/.ssh/config.${NC}"
fi

# 4. Buat service systemd auto-reconnect
echo -e "${YELLOW}[3/5] Memasang systemd service ${SERVICE_NAME}.service...${NC}"
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
systemctl restart "${SERVICE_NAME}.service" 2>/dev/null || true
echo -e "${GREEN}✓ Service ${SERVICE_NAME}.service aktif & berjalan.${NC}"

# 5. Pasang ke recover.sh (Anti-VM Replace)
RECOVER_SH="/home/hatch/workspace/vm-recovery/recover.sh"
if [ -f "$RECOVER_SH" ]; then
    echo -e "${YELLOW}[4/5] Mendaftarkan ke $RECOVER_SH agar tahan VM replace...${NC}"
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
        echo -e "${GREEN}✓ Service sudah terdaftar di recover.sh.${NC}"
    fi
fi

PUB_KEY_CONTENT=$(cat "${SSH_KEY}.pub")

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}🎉 SETUP WORKER VM ${WORKER_ID} SELESAI!${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "\n${YELLOW}KUNCI PUBLIK (PUBLIC KEY) WORKER VM ${WORKER_ID}:${NC}"
echo -e "${GREEN}${PUB_KEY_CONTENT}${NC}\n"

echo -e "${CYAN}------------------------------------------------------${NC}"
echo -e "${YELLOW}LANGKAH BERIKUTNYA DI VM 1 (CENTRAL HUB):${NC}"
echo -e "Jalankan perintah ini di VM 1 (atau berikan ke AI Muse VM 1):"
echo -e "${CYAN}curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/register-vm1.sh | bash -s \"${PUB_KEY_CONTENT}\" ${REMOTE_PORT} \"VM${WORKER_ID}\"${NC}"
echo -e "${CYAN}------------------------------------------------------${NC}\n"
