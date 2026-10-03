#!/bin/bash
# ==============================================================================
# INSTALL-MUSE-BRIDGE.SH — Installer Mandiri Muse Bridge (Port 20129)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Memasang Muse Bridge (Mailbox mode) di VM worker agar 9Router bisa
# memanggil Muse Spark AI via format OpenAI-compatible API.
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${CYAN}======================================================================${NC}"
echo -e "${CYAN}    🤖 INSTALLER MUSE BRIDGE (PORT 20129)                               ${NC}"
echo -e "${CYAN}======================================================================${NC}\n"

BRIDGE_DIR="/home/hatch/muse-bridge"
QUEUE_DIR="/home/hatch/workspace/9router-bridge/queue"
BRIDGE_KEY="${1:-e58aed37c658ed6a0793ac5a1b2920ad12b281f13993fa577d7b724a81761f60}"
PORT="${2:-20129}"

# 1. Pastikan Node.js terpasang
if ! command -v node >/dev/null 2>&1; then
    echo -e "${YELLOW}[1/5] Memasang Node.js...${NC}"
    apt-get update -qq && apt-get install -y -qq nodejs
else
    echo -e "${GREEN}[1/5] Node.js terdeteksi: $(node -v)${NC}"
fi

# 2. Buat direktori kerja & antrean mailbox
echo -e "${YELLOW}[2/5] Menyiapkan direktori bridge & queue...${NC}"
mkdir -p "$BRIDGE_DIR" "$QUEUE_DIR"
chmod 755 "$BRIDGE_DIR" "$QUEUE_DIR"

# 3. Pasang config.json
cat > "${BRIDGE_DIR}/config.json" << EOF
{
  "port": ${PORT},
  "bridge_key": "${BRIDGE_KEY}",
  "meta_api_key": ""
}
EOF
chmod 600 "${BRIDGE_DIR}/config.json"

# 4. Pasang bridge.js jika belum ada
if [ ! -f "${BRIDGE_DIR}/bridge.js" ]; then
    echo -e "${YELLOW}[3/5] Mengunduh bridge.js...${NC}"
    if [ -f "$(dirname "$0")/muse-bridge/bridge.js" ]; then
        cp "$(dirname "$0")/muse-bridge/bridge.js" "${BRIDGE_DIR}/bridge.js"
    else
        curl -sSL "https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/muse-bridge/bridge.js" -o "${BRIDGE_DIR}/bridge.js"
    fi
    chmod 644 "${BRIDGE_DIR}/bridge.js"
    echo -e "${GREEN}✓ bridge.js berhasil dipasang.${NC}"
else
    echo -e "${GREEN}[3/5] bridge.js sudah ada di ${BRIDGE_DIR}/bridge.js.${NC}"
fi

# 5. Pasang dan aktifkan systemd service muse-bridge
echo -e "${YELLOW}[4/5] Memasang systemd service muse-bridge.service...${NC}"
cat > /etc/systemd/system/muse-bridge.service << EOF
[Unit]
Description=Muse mailbox bridge (9Router -> Muse worker)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/hatch/muse-bridge
Environment=HOME=/home/hatch
Environment=CURL_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
Environment=SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
Environment=NODE_EXTRA_CA_CERTS=/run/hatch/egress-tls/ca-bundle.pem
ExecStart=/usr/bin/node /home/hatch/muse-bridge/bridge.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable muse-bridge.service
systemctl restart muse-bridge.service
sleep 2

# 6. Pasang ke recover.sh (Anti VM Replace)
RECOVER_SH="/home/hatch/workspace/vm-recovery/recover.sh"
if [ -f "$RECOVER_SH" ]; then
    echo -e "${YELLOW}[5/5] Mendaftarkan ke recover.sh...${NC}"
    if ! grep -q "muse-bridge.service" "$RECOVER_SH"; then
        cat >> "$RECOVER_SH" << 'EOF'

# ---- Muse Bridge Service (Port 20129) ----
if [ ! -f /etc/systemd/system/muse-bridge.service ] && [ -d /home/hatch/muse-bridge ]; then
  cat > /etc/systemd/system/muse-bridge.service << 'UNIT'
[Unit]
Description=Muse mailbox bridge (9Router -> Muse worker)
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/home/hatch/muse-bridge
Environment=HOME=/home/hatch
Environment=CURL_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
Environment=SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
Environment=NODE_EXTRA_CA_CERTS=/run/hatch/egress-tls/ca-bundle.pem
ExecStart=/usr/bin/node /home/hatch/muse-bridge/bridge.js
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now muse-bridge.service
fi
EOF
        echo -e "${GREEN}✓ Muse Bridge berhasil diamankan di recover.sh.${NC}"
    else
        echo -e "${GREEN}✓ Muse Bridge sudah ada di recover.sh.${NC}"
    fi
fi

# 7. Uji Status Service
if curl -s "http://127.0.0.1:${PORT}/health" | grep -q "ok"; then
    echo -e "\n${GREEN}${BOLD}🎉 SUKSES! MUSE BRIDGE AKTIF DI PORT ${PORT}!${NC}"
    echo -e "Healthcheck: ${GREEN}$(curl -s "http://127.0.0.1:${PORT}/health")${NC}\n"
else
    echo -e "\n${YELLOW}Catatan: Service sudah dinyalakan, silakan periksa statusnya:${NC}"
    systemctl status muse-bridge --no-pager || true
fi
