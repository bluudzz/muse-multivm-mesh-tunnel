#!/bin/bash
# ==============================================================================
# REGISTER-VM1.SH — Pendaftaran Kunci Worker di VM 1 (Central Hub 9Router)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Penggunaan:
#   ./register-vm1.sh "<PUBLIC_KEY>" [PORT_REMOTE] [NAMA_WORKER]
# Contoh:
#   ./register-vm1.sh "ssh-ed25519 AAA..." 20130 "VM2"
#   ./register-vm1.sh "ssh-ed25519 AAA..." 20131 "VM3"
# ==============================================================================
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VM_PUBKEY="${1:-}"
REMOTE_PORT="${2:-20130}"
WORKER_NAME="${3:-VM2}"

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}  MUSE MESH TUNNEL: REGISTRAR WORKER ${WORKER_NAME} DI VM 1   ${NC}"
echo -e "${CYAN}======================================================${NC}"

if [ -z "$VM_PUBKEY" ]; then
    echo -e "${YELLOW}Masukkan Public Key dari ${WORKER_NAME} (ssh-ed25519 ...):${NC}"
    read -r VM_PUBKEY
fi

if [ -z "$VM_PUBKEY" ]; then
    echo -e "${RED}Error: Public key tidak boleh kosong!${NC}" >&2
    exit 1
fi

mkdir -p /home/hatch/.ssh
chmod 700 /home/hatch/.ssh

AUTH_KEYS="/home/hatch/.ssh/authorized_keys"
AUTH_BACKUP="/home/hatch/.ssh/authorized_keys_laptop"

echo -e "${YELLOW}[1/3] Menambahkan public key ${WORKER_NAME} ke authorized_keys...${NC}"
if ! grep -q "$VM_PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
    echo "$VM_PUBKEY" >> "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    echo -e "${GREEN}✓ Berhasil ditambahkan ke $AUTH_KEYS.${NC}"
else
    echo -e "${GREEN}✓ Public key sudah terdaftar di $AUTH_KEYS.${NC}"
fi

# Simpan juga ke backup authorized_keys_laptop jika ada
if [ -f "$AUTH_BACKUP" ]; then
    if ! grep -q "$VM_PUBKEY" "$AUTH_BACKUP" 2>/dev/null; then
        echo "$VM_PUBKEY" >> "$AUTH_BACKUP"
        echo -e "${GREEN}✓ Berhasil disimpan ke backup $AUTH_BACKUP.${NC}"
    fi
fi

echo -e "${YELLOW}[2/3] Menunggu sinkronisasi reverse tunnel dari ${WORKER_NAME}...${NC}"
sleep 2

# Cek port remote
echo -e "${YELLOW}[3/3] Memeriksa status port lokal ${REMOTE_PORT}...${NC}"
if ss -tln | grep -q ":${REMOTE_PORT}"; then
    echo -e "${GREEN}✓ PORT ${REMOTE_PORT} AKTIF! Tunnel dari ${WORKER_NAME} telah tersambung.${NC}"
    echo -e "\n${CYAN}Tes Panggilan Model Langsung:${NC}"
    curl -s --connect-timeout 3 "http://127.0.0.1:${REMOTE_PORT}/v1/models" || true
    echo -e "\n"
else
    echo -e "${YELLOW}Port ${REMOTE_PORT} belum aktif.${NC}"
    echo -e "Pastikan service tunnel di ${WORKER_NAME} sudah dinyalakan."
fi

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}Pendaftaran kunci ${WORKER_NAME} di VM 1 selesai!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${CYAN}Konfigurasi Provider 9Router untuk ${WORKER_NAME}:${NC}"
echo -e "- Provider Name : ${YELLOW}Muse-${WORKER_NAME}${NC}"
echo -e "- Base URL      : ${YELLOW}http://127.0.0.1:${REMOTE_PORT}/v1${NC}"
echo -e "- Model Name    : ${YELLOW}muse/muse-spark-${WORKER_NAME,,}${NC}\n"
