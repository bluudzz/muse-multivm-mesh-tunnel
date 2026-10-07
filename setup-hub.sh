#!/bin/bash
# ==============================================================================
# SETUP-HUB.SH — Installer Otomatis untuk VM Utama (VM 1 Central Hub)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Menyiapkan konfigurasi SSH, membuat Kunci Induk (Master Mesh Key),
# mengamankan ke authorized_keys root & hatch, serta recover.sh.
# ==============================================================================
set -e

# Otomatis muat environment proxy jika berjalan di ekosistem VM Hatch
if [ -f /home/hatch/server-control/proxy.env ]; then
    set -a; . /home/hatch/server-control/proxy.env; set +a
elif [ -f /home/hatch/.proxy-env ]; then
    set -a; . /home/hatch/.proxy-env; set +a
fi

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${CYAN}======================================================================${NC}"
echo -e "${CYAN}    🌐 MUSE MULTI-VM MESH TUNNEL: SETUP VM UTAMA (CENTRAL HUB 1)       ${NC}"
echo -e "${CYAN}======================================================================${NC}\n"

# 1. Pastikan folder .ssh ada untuk root dan hatch
mkdir -p /home/hatch/.ssh /root/.ssh
chmod 700 /home/hatch/.ssh /root/.ssh

KEY_PATH="/home/hatch/.ssh/id_mesh_master"
AUTH_HATCH="/home/hatch/.ssh/authorized_keys"
AUTH_ROOT="/root/.ssh/authorized_keys"
AUTH_BACKUP="/home/hatch/.ssh/authorized_keys_laptop"
RECOVER_SH="/home/hatch/workspace/vm-recovery/recover.sh"

# 2. Buat Master Key jika belum ada
if [ ! -f "$KEY_PATH" ]; then
    echo -e "${YELLOW}[1/4] Membuat Kunci Induk baru (ed25519)...${NC}"
    ssh-keygen -t ed25519 -N "" -f "$KEY_PATH" -C "mesh-master@hatch-cluster"
    chmod 600 "$KEY_PATH"
    chmod 644 "${KEY_PATH}.pub"
    echo -e "${GREEN}✓ Kunci Induk berhasil dibuat.${NC}"
else
    echo -e "${GREEN}[1/4] Menggunakan Kunci Induk yang sudah ada di: ${KEY_PATH}${NC}"
fi

PUB_KEY=$(cat "${KEY_PATH}.pub")

# 3. Daftarkan Public Key ke authorized_keys ROOT dan HATCH
echo -e "${YELLOW}[2/4] Memasang Public Key ke authorized_keys (Root & Hatch)...${NC}"

# Untuk user root (WAJIB karena worker login sebagai root)
touch "$AUTH_ROOT"
if ! grep -q "$PUB_KEY" "$AUTH_ROOT" 2>/dev/null; then
    echo "$PUB_KEY" >> "$AUTH_ROOT"
    chmod 600 "$AUTH_ROOT"
    echo -e "${GREEN}✓ Public key dipasang di ${AUTH_ROOT} (root).${NC}"
else
    echo -e "${GREEN}✓ Public key sudah ada di ${AUTH_ROOT}.${NC}"
fi

# Untuk user hatch
touch "$AUTH_HATCH"
if ! grep -q "$PUB_KEY" "$AUTH_HATCH" 2>/dev/null; then
    echo "$PUB_KEY" >> "$AUTH_HATCH"
    chmod 600 "$AUTH_HATCH"
    echo -e "${GREEN}✓ Public key dipasang di ${AUTH_HATCH} (hatch).${NC}"
else
    echo -e "${GREEN}✓ Public key sudah ada di ${AUTH_HATCH}.${NC}"
fi

if [ -f "$AUTH_BACKUP" ]; then
    if ! grep -q "$PUB_KEY" "$AUTH_BACKUP" 2>/dev/null; then
        echo "$PUB_KEY" >> "$AUTH_BACKUP"
        echo -e "${GREEN}✓ Disimpan ke backup ${AUTH_BACKUP}.${NC}"
    fi
fi

# 4. Amankan ke recover.sh (Anti VM Replace)
echo -e "${YELLOW}[3/5] Mendaftarkan ke recover.sh (Anti-VM Replace)...${NC}"
mkdir -p /home/hatch/scripts /home/hatch/workspace/vm-recovery
if [ -f "$RECOVER_SH" ]; then
    if ! grep -q "mesh-master@hatch-cluster" "$RECOVER_SH"; then
        cat >> "$RECOVER_SH" << EOF

# ---- Muse Mesh Tunnel Master Key & Mesh CLI ----
mkdir -p /root/.ssh /home/hatch/.ssh
chmod 700 /root/.ssh /home/hatch/.ssh
if ! grep -q "mesh-master@hatch-cluster" /root/.ssh/authorized_keys 2>/dev/null; then
  echo "${PUB_KEY}" >> /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi
if ! grep -q "mesh-master@hatch-cluster" /home/hatch/.ssh/authorized_keys 2>/dev/null; then
  echo "${PUB_KEY}" >> /home/hatch/.ssh/authorized_keys
  chmod 600 /home/hatch/.ssh/authorized_keys
fi

# Restore mesh CLI binary jika VM direplace
if [ -f /home/hatch/scripts/mesh-ctl.sh ] && [ ! -f /usr/local/bin/mesh ]; then
  cp /home/hatch/scripts/mesh-ctl.sh /usr/local/bin/mesh
  chmod +x /usr/local/bin/mesh
fi

# Restore mesh-watchdog timer jika VM direplace
if [ ! -f /etc/systemd/system/mesh-watchdog.service ]; then
  cat > /etc/systemd/system/mesh-watchdog.service << 'UNIT'
[Unit]
Description=Muse Mesh Key Synchronization Watchdog
After=network.target 9router.service
[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/mesh sync-keys
UNIT
fi
if [ ! -f /etc/systemd/system/mesh-watchdog.timer ]; then
  cat > /etc/systemd/system/mesh-watchdog.timer << 'UNIT'
[Unit]
Description=Run Muse Mesh Key Synchronization Watchdog Every Minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload
  systemctl enable --now mesh-watchdog.timer
fi
EOF
        echo -e "${GREEN}✓ Berhasil diamankan di recover.sh.${NC}"
    else
        echo -e "${GREEN}✓ Sudah terdaftar di recover.sh.${NC}"
    fi
fi

# 5. Pasang CLI Orchestrator 'mesh' & Auto-Sync Watchdog di VM 1
echo -e "${YELLOW}[4/5] Memasang Tool Kendali Pusat 'mesh' & Watchdog di VM 1...${NC}"
mkdir -p /home/hatch/scripts /usr/local/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/scripts/mesh-ctl.sh" ]; then
    cp "${SCRIPT_DIR}/scripts/mesh-ctl.sh" /home/hatch/scripts/mesh-ctl.sh
    cp "${SCRIPT_DIR}/scripts/mesh-ctl.sh" /usr/local/bin/mesh
else
    curl -sSL "https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/scripts/mesh-ctl.sh" -o /home/hatch/scripts/mesh-ctl.sh || true
    if [ -f /home/hatch/scripts/mesh-ctl.sh ]; then
        cp /home/hatch/scripts/mesh-ctl.sh /usr/local/bin/mesh
    fi
fi
chmod +x /home/hatch/scripts/mesh-ctl.sh /usr/local/bin/mesh 2>/dev/null || true

# Pasang service & timer auto-sync watchdog di VM 1
cat > /etc/systemd/system/mesh-watchdog.service << 'UNIT'
[Unit]
Description=Muse Mesh Key Synchronization Watchdog
After=network.target 9router.service
[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/mesh sync-keys
UNIT

cat > /etc/systemd/system/mesh-watchdog.timer << 'UNIT'
[Unit]
Description=Run Muse Mesh Key Synchronization Watchdog Every Minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now mesh-watchdog.timer 2>/dev/null || true

# Tambahkan alias SSH client config untuk kemudahan (ssh vm2, ssh vm3, dst.)
SSH_CONF_BLOCK="
# ---- Muse Mesh Worker Control Aliases ----
Match host vm[0-9]*
    HostName 127.0.0.1
    User root
    IdentityFile ${KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
"
touch /home/hatch/.ssh/config /root/.ssh/config
if ! grep -q "Match host vm" /home/hatch/.ssh/config 2>/dev/null; then
    echo "$SSH_CONF_BLOCK" >> /home/hatch/.ssh/config
    chmod 600 /home/hatch/.ssh/config
fi
if ! grep -q "Match host vm" /root/.ssh/config 2>/dev/null; then
    echo "$SSH_CONF_BLOCK" >> /root/.ssh/config
    chmod 600 /root/.ssh/config
fi
echo -e "${GREEN}✓ Tool kendali 'mesh' berhasil dipasang di /usr/local/bin/mesh.${NC}"

# 6. Buat Token Base64 dari Private Key
echo -e "${YELLOW}[5/5] Menghasilkan Token Kunci Induk untuk Worker...${NC}"
TOKEN=$(base64 -w 0 "$KEY_PATH" 2>/dev/null || base64 "$KEY_PATH" | tr -d '\r\n')

# 7. Tampilkan Banner Token & Panduan Kontrol
echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 SETUP VM UTAMA (HUB PUSAT KENDALI) SELESAI & AKTIF 100%!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "\n${YELLOW}${BOLD}🔑 SALIN TOKEN KUNCI INDUK DI BAWAH INI:${NC}"
echo -e "${CYAN}----------------------------------------------------------------------${NC}"
echo -e "${BOLD}${TOKEN}${NC}"
echo -e "${CYAN}----------------------------------------------------------------------${NC}"
echo -e "${YELLOW}⚠️  Token ini sudah terdaftar di root dan hatch VM 1 ini.${NC}\n"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}🎮 PANDUAN MENGAKSES & MENGENDALIKAN WORKER DARI VM 1:${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "Tool ${BOLD}mesh${NC} siap digunakan langsung dari terminal VM 1:"
echo -e "  - ${GREEN}mesh list${NC}                     : Cek status semua worker (SSH & Model AI)"
echo -e "  - ${GREEN}mesh ssh 2${NC}                    : Masuk ke terminal shell VM 2 langsung!"
echo -e "  - ${GREEN}mesh exec 2 \"uptime\"${NC}         : Jalankan perintah di VM 2 dari VM 1"
echo -e "  - ${GREEN}mesh exec all \"df -h\"${NC}        : Jalankan perintah ke SEMUA worker serentak"
echo -e "  - ${GREEN}mesh push 2 <lokal> <remote>${NC}  : Kirim file dari VM 1 ke VM 2"
echo -e "  - ${GREEN}mesh restart 2 muse-bridge${NC}   : Restart service di worker dari jauh\n"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}📋 LANGKAH SELANJUTNYA: JALANKAN DI VM WORKER BARU${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "\n${YELLOW}Buka terminal di VM Worker baru (VM 2, VM 3, dst.), lalu jalankan:${NC}"
echo -e "${CYAN}curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash${NC}"
echo -e "*(Skrip di worker akan otomatis menanyakan nomor ID worker, host SSH, dan token)*\n"
echo -e "${YELLOW}Atau jalankan langsung dengan menyertakan parameter:${NC}"
echo -e "${CYAN}curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 2 \"${TOKEN}\" \"<HOST_SSH_ANDA>\"${NC}\n"
echo -e "${GREEN}======================================================================${NC}\n"
