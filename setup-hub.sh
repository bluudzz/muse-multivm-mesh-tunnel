#!/bin/bash
# ==============================================================================
# SETUP-HUB.SH — Installer Otomatis untuk VM Utama (VM 1 Central Hub)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Menyiapkan konfigurasi SSH, membuat Kunci Induk (Master Mesh Key),
# mengamankan ke authorized_keys root & hatch, serta recover.sh.
# ==============================================================================
set -e

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
echo -e "${YELLOW}[3/4] Mendaftarkan ke recover.sh (Anti-VM Replace)...${NC}"
if [ -f "$RECOVER_SH" ]; then
    if ! grep -q "mesh-master@hatch-cluster" "$RECOVER_SH"; then
        cat >> "$RECOVER_SH" << EOF

# ---- Muse Mesh Tunnel Master Key (Root & Hatch) ----
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
EOF
        echo -e "${GREEN}✓ Berhasil diamankan di recover.sh.${NC}"
    else
        echo -e "${GREEN}✓ Sudah terdaftar di recover.sh.${NC}"
    fi
fi

# 5. Buat Token Base64 dari Private Key
echo -e "${YELLOW}[4/4] Menghasilkan Token Kunci Induk untuk Worker...${NC}"
TOKEN=$(base64 -w 0 "$KEY_PATH" 2>/dev/null || base64 "$KEY_PATH" | tr -d '\r\n')

# 6. Tampilkan Banner Token
echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 SETUP VM UTAMA (HUB) SELESAI & AKTIF 100%!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "\n${YELLOW}${BOLD}🔑 SALIN TOKEN KUNCI INDUK DI BAWAH INI:${NC}"
echo -e "${CYAN}----------------------------------------------------------------------${NC}"
echo -e "${BOLD}${TOKEN}${NC}"
echo -e "${CYAN}----------------------------------------------------------------------${NC}"
echo -e "${YELLOW}⚠️  Token ini sudah terdaftar di root dan hatch VM 1 ini.${NC}\n"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}📋 LANGKAH SELANJUTNYA: JALANKAN DI VM WORKER BARU${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "\n${YELLOW}▶ Jika memasang di VM 2 (Worker 1):${NC}"
echo -e "Buka terminal di VM 2 lalu jalankan:"
echo -e "${CYAN}curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 2 \"${TOKEN}\"${NC}"

echo -e "\n${YELLOW}▶ Jika memasang di VM 3 (Worker 2):${NC}"
echo -e "Buka terminal di VM 3 lalu jalankan:"
echo -e "${CYAN}curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 3 \"${TOKEN}\"${NC}\n"
echo -e "${GREEN}======================================================================${NC}\n"
