#!/bin/bash
# ==============================================================================
# INSTALL-VM2.SH — Otomatisasi Setup SSH Reverse Tunnel di VM 2 (Worker Muse)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}  MUSE MULTI-VM MESH TUNNEL: INSTALLER VM 2          ${NC}"
echo -e "${CYAN}======================================================${NC}"

VM1_HOST="${1:-ssh.ourme.my.id}"
LOCAL_PORT="${2:-20129}"
REMOTE_PORT="${3:-20130}"
SSH_USER="root"
SSH_KEY="/home/hatch/.ssh/id_vm2"

# 1. Pastikan folder .ssh ada
mkdir -p /home/hatch/.ssh
chmod 700 /home/hatch/.ssh

# 2. Generate SSH Key jika belum ada
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${YELLOW}[1/5] Membuat SSH Key ed25519 baru di VM 2...${NC}"
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    chmod 644 "${SSH_KEY}.pub"
else
    echo -e "${GREEN}[1/5] SSH Key sudah ada: $SSH_KEY${NC}"
fi

# 3. Konfigurasi SSH Config dengan Cloudflared ProxyCommand
echo -e "${YELLOW}[2/5] Mengonfigurasi /home/hatch/.ssh/config...${NC}"
if ! grep -q "Host vm1-hub" /home/hatch/.ssh/config 2>/dev/null; then
    cat >> /home/hatch/.ssh/config << EOF

# ---- Muse Mesh Tunnel: Hub VM 1 ----
Host vm1-hub
    HostName $VM1_HOST
    User $SSH_USER
    IdentityFile $SSH_KEY
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
EOF
    chmod 600 /home/hatch/.ssh/config
    echo -e "${GREEN}✓ Konfigurasi SSH berhasil ditambahkan.${NC}"
else
    echo -e "${GREEN}✓ Entry vm1-hub sudah terdaftar di ~/.ssh/config.${NC}"
fi

# 4. Buat systemd service reverse-tunnel-vm1.service
echo -e "${YELLOW}[3/5] Memasang systemd service reverse-tunnel-vm1.service...${NC}"
cat > /etc/systemd/system/reverse-tunnel-vm1.service << EOF
[Unit]
Description=SSH Reverse Tunnel ke 9Router VM 1
After=network.target muse-bridge.service
Wants=muse-bridge.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -N -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} vm1-hub
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable reverse-tunnel-vm1.service
echo -e "${GREEN}✓ Service reverse tunnel berhasil dipasang & diaktifkan.${NC}"

# 5. Pasang ke recover.sh (Anti VM Replace)
RECOVER_SH="/home/hatch/workspace/vm-recovery/recover.sh"
if [ -f "$RECOVER_SH" ]; then
    echo -e "${YELLOW}[4/5] Mendaftarkan ke $RECOVER_SH agar tahan VM replace...${NC}"
    if ! grep -q "reverse-tunnel-vm1" "$RECOVER_SH"; then
        cat >> "$RECOVER_SH" << 'EOF'

# ---- Muse Multi-VM Reverse Tunnel to VM 1 ----
if [ ! -f /etc/systemd/system/reverse-tunnel-vm1.service ]; then
  cat > /etc/systemd/system/reverse-tunnel-vm1.service << 'UNIT'
[Unit]
Description=SSH Reverse Tunnel ke 9Router VM 1
After=network.target muse-bridge.service
Wants=muse-bridge.service
[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -N -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R 20130:127.0.0.1:20129 vm1-hub
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now reverse-tunnel-vm1.service
fi
EOF
        echo -e "${GREEN}✓ Berhasil ditambahkan ke recover.sh.${NC}"
    else
        echo -e "${GREEN}✓ Blok recovery sudah ada di recover.sh.${NC}"
    fi
fi

# Nyalakan service sekarang
systemctl restart reverse-tunnel-vm1.service || true

# 6. Tampilkan petunjuk final & Public Key
echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}  INSTALASI DI VM 2 SELESAI!                          ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "${YELLOW}KUNCI PUBLIK VM 2 ANDA (Salin baris di bawah ini):${NC}"
echo -e "------------------------------------------------------"
cat "${SSH_KEY}.pub"
echo -e "------------------------------------------------------\n"
echo -e "${CYAN}LANGKAH BERIKUTNYA DI VM 1:${NC}"
echo -e "1. Buka terminal di VM 1."
echo -e "2. Jalankan perintah ini:"
echo -e "   ${YELLOW}curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/register-vm1.sh | bash -s \"$(cat "${SSH_KEY}.pub")\"${NC}"
echo -e "\n"
