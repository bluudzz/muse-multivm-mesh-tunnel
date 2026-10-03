#!/bin/bash
# ==============================================================================
# REGISTER-VM1.SH — Skrip Pendaftaran Kunci VM 2 di VM 1 (Central Hub 9Router)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}  MUSE MULTI-VM MESH TUNNEL: REGISTRAR VM 1          ${NC}"
echo -e "${CYAN}======================================================${NC}"

VM2_PUBKEY="${1:-}"

if [ -z "$VM2_PUBKEY" ]; then
    echo -e "${YELLOW}Masukkan Public Key dari VM 2 (ssh-ed25519 ...):${NC}"
    read -r VM2_PUBKEY
fi

if [ -z "$VM2_PUBKEY" ]; then
    echo -e "${RED}Error: Public key tidak boleh kosong!${NC}" >&2
    exit 1
fi

mkdir -p /home/hatch/.ssh
chmod 700 /home/hatch/.ssh

AUTH_KEYS="/home/hatch/.ssh/authorized_keys"
AUTH_BACKUP="/home/hatch/.ssh/authorized_keys_laptop"

echo -e "${YELLOW}[1/3] Menambahkan public key VM 2 ke authorized_keys...${NC}"
if ! grep -q "$VM2_PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
    echo "$VM2_PUBKEY" >> "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    echo -e "${GREEN}✓ Berhasil ditambahkan ke $AUTH_KEYS.${NC}"
else
    echo -e "${GREEN}✓ Public key sudah terdaftar di $AUTH_KEYS.${NC}"
fi

# Simpan juga ke backup authorized_keys_laptop
if [ -f "$AUTH_BACKUP" ]; then
    if ! grep -q "$VM2_PUBKEY" "$AUTH_BACKUP" 2>/dev/null; then
        echo "$VM2_PUBKEY" >> "$AUTH_BACKUP"
        echo -e "${GREEN}✓ Berhasil disimpan ke backup $AUTH_BACKUP.${NC}"
    fi
fi

echo -e "${YELLOW}[2/3] Menunggu koneksi reverse tunnel dari VM 2...${NC}"
sleep 2

# Cek port 20130
echo -e "${YELLOW}[3/3] Memeriksa status port lokal 20130...${NC}"
if ss -tln | grep -q ":20130"; then
    echo -e "${GREEN}✓ PORT 20130 AKTIF! Tunnel dari VM 2 telah tersambung.${NC}"
    echo -e "\n${CYAN}Tes Panggilan Model:${NC}"
    curl -s http://127.0.0.1:20130/v1/models || true
    echo -e "\n"
else
    echo -e "${YELLOW}Port 20130 belum terdeteksi aktif saat ini.${NC}"
    echo -e "Pastikan service 'reverse-tunnel-vm1' di VM 2 sudah dinyalakan."
fi

echo -e "\n${GREEN}Pendaftaran kunci di VM 1 selesai!${NC}"
echo -e "${CYAN}Silakan daftarkan Base URL ini ke 9Router:${NC}"
echo -e "${YELLOW}👉 Base URL: http://127.0.0.1:20130/v1${NC}\n"
