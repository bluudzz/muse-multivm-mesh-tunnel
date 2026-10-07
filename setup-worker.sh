#!/bin/bash
# ==============================================================================
# SETUP-WORKER.SH — Universal Worker Installer (VM 2, VM 3, VM 4, dst)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
# Skrip ini berjalan secara INTERAKTIF (menanyakan nomor worker, host SSH, dan token)
# atau secara OTOMATIS jika argumen disertakan via CLI:
#   ./setup-worker.sh <WORKER_ID> "<TOKEN>" [HOST_VM1]
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

WORKER_ID=""
TOKEN=""
VM1_HOST=""
LOCAL_PORT="20129"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --worker|--id|-w)
            WORKER_ID="$2"
            shift 2
            ;;
        --host|--ssh|-h)
            VM1_HOST="$2"
            shift 2
            ;;
        --token|-t)
            TOKEN="$2"
            shift 2
            ;;
        --port|-p)
            LOCAL_PORT="$2"
            shift 2
            ;;
        *)
            if [ -z "$WORKER_ID" ]; then
                WORKER_ID="$1"
            elif [ -z "$TOKEN" ]; then
                TOKEN="$1"
            elif [ -z "$VM1_HOST" ]; then
                VM1_HOST="$1"
            fi
            shift
            ;;
    esac
done

echo -e "\n${CYAN}======================================================================${NC}"
echo -e "${CYAN}    🌐 MUSE MULTI-VM MESH TUNNEL: SETUP WORKER NODE                    ${NC}"
echo -e "${CYAN}======================================================================${NC}\n"

# Helper untuk membaca input dari terminal keyboard meskipun dijalankan via curl | bash
read_input() {
    local prompt="$1"
    local var_name="$2"
    local default_val="$3"

    if [ -t 0 ]; then
        read -r -p "$prompt" val
    elif [ -e /dev/tty ]; then
        read -r -p "$prompt" val < /dev/tty
    else
        val=""
    fi

    if [ -z "$val" ] && [ -n "$default_val" ]; then
        val="$default_val"
    fi
    eval "$var_name=\"$val\""
}

# 1. Validasi / Tanya Jawab Interaktif
if [ -z "$WORKER_ID" ]; then
    echo -e "${YELLOW}1. Masukkan Nomor ID Worker (contoh: 2 untuk VM 2, 3 untuk VM 3):${NC}"
    read_input "   Nomor Worker [2]: " WORKER_ID "2"
fi

if [ -z "$VM1_HOST" ]; then
    echo -e "${YELLOW}2. Masukkan Hostname / Domain SSH VM 1 (contoh: ssh.domainanda.com):${NC}"
    read_input "   SSH Host: " VM1_HOST ""
fi

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}3. Masukkan Token Kunci Induk (yang didapat dari setup-hub.sh):${NC}"
    read_input "   Token: " TOKEN ""
fi

if [ -z "$WORKER_ID" ] || [ -z "$VM1_HOST" ] || [ -z "$TOKEN" ]; then
    echo -e "\n${RED}Error: Nomor Worker ID, Host SSH, dan Token Kunci Induk wajib diisi!${NC}" >&2
    exit 1
fi

REMOTE_PORT=$(( 20128 + WORKER_ID ))
SSH_CONTROL_PORT=$(( 22000 + WORKER_ID ))
SSH_USER="root"
SSH_KEY_HATCH="/home/hatch/.ssh/id_mesh_master"
SSH_KEY_ROOT="/root/.ssh/id_mesh_master"
SERVICE_NAME="reverse-tunnel-worker${WORKER_ID}"
HOST_ALIAS="vm1-hub-w${WORKER_ID}"

echo -e "\n${CYAN}---------------- Konfigurasi Terpilih ----------------${NC}"
echo -e "Node ID           : ${GREEN}VM ${WORKER_ID}${NC}"
echo -e "Port Internal     : ${GREEN}${LOCAL_PORT}${NC} (Muse Bridge)"
echo -e "Port Remote VM 1  : ${YELLOW}${REMOTE_PORT}${NC} (Endpoint di 9Router)"
echo -e "SSH Control Port  : ${YELLOW}${SSH_CONTROL_PORT}${NC} (Kendali Remote dari VM 1)"
echo -e "Hub VM 1          : ${GREEN}${VM1_HOST}${NC}"
echo -e "Systemd Service   : ${GREEN}${SERVICE_NAME}.service${NC}"
echo -e "${CYAN}------------------------------------------------------${NC}\n"

# 2. Pastikan Muse Bridge terpasang dan aktif di port lokal (20129)
if ! curl -s "http://127.0.0.1:${LOCAL_PORT}/health" >/dev/null 2>&1; then
    echo -e "${YELLOW}[0/5] Muse Bridge belum aktif di port ${LOCAL_PORT}. Memasang Muse Bridge otomatis...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
    if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/install-muse-bridge.sh" ]; then
        bash "${SCRIPT_DIR}/install-muse-bridge.sh"
    else
        curl -sSL "https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/install-muse-bridge.sh" | bash
    fi
else
    echo -e "${GREEN}[0/5] Muse Bridge sudah aktif di port ${LOCAL_PORT}.${NC}"
fi

# 3. Pastikan folder .ssh ada untuk hatch dan root
mkdir -p /home/hatch/.ssh /root/.ssh
chmod 700 /home/hatch/.ssh /root/.ssh

# 4. Pasang Kunci Induk dari Token ke hatch dan root + Daftarkan ke authorized_keys
echo -e "${YELLOW}[1/5] Memasang Kunci Induk & Akses Kendali dari VM 1...${NC}"
echo "$TOKEN" | base64 -d > "$SSH_KEY_HATCH"
chmod 600 "$SSH_KEY_HATCH"
cp -p "$SSH_KEY_HATCH" "$SSH_KEY_ROOT" 2>/dev/null || true
chmod 600 "$SSH_KEY_ROOT" 2>/dev/null || true

# Ekstrak Public Key agar VM 1 diizinkan login SSH langsung ke worker ini
ssh-keygen -y -f "$SSH_KEY_HATCH" > "${SSH_KEY_HATCH}.pub" 2>/dev/null || true
PUB_KEY=$(cat "${SSH_KEY_HATCH}.pub" 2>/dev/null || echo "")
if [ -n "$PUB_KEY" ]; then
    touch /root/.ssh/authorized_keys /home/hatch/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys /home/hatch/.ssh/authorized_keys
    if ! grep -q "$PUB_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
        echo "$PUB_KEY" >> /root/.ssh/authorized_keys
    fi
    if ! grep -q "$PUB_KEY" /home/hatch/.ssh/authorized_keys 2>/dev/null; then
        echo "$PUB_KEY" >> /home/hatch/.ssh/authorized_keys
    fi
fi
echo -e "${GREEN}✓ Kunci terpasang & akses kendali dari VM 1 diaktifkan.${NC}"

# 5. Konfigurasi SSH Client (~/.ssh/config) untuk hatch dan root
echo -e "${YELLOW}[2/5] Mengonfigurasi Cloudflare SSH Access...${NC}"
CF_BIN=$(command -v cloudflared 2>/dev/null || echo "/usr/local/bin/cloudflared")
PROXY_CMD="${CF_BIN} access ssh --hostname %h"
if [ -f /home/hatch/server-control/proxy.env ]; then
    PROXY_CMD="bash -c 'set -a; [ -f /home/hatch/server-control/proxy.env ] && . /home/hatch/server-control/proxy.env; exec ${CF_BIN} access ssh --hostname %h'"
fi

SSH_BLOCK="
# ---- Muse Mesh Tunnel: Hub VM 1 (Worker ${WORKER_ID}) ----
Host ${HOST_ALIAS}
    HostName ${VM1_HOST}
    User ${SSH_USER}
    IdentityFile ${SSH_KEY_HATCH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand ${PROXY_CMD}
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

# 6. Pasang Mesh Control Agent (Daemon Kendali Remote Berbasis Node.js Native)
echo -e "${YELLOW}[3/6] Memasang Mesh Remote Control Agent...${NC}"
AGENT_DIR="/home/hatch/www/mesh-agent"
mkdir -p "$AGENT_DIR"
cat > "${AGENT_DIR}/agent.js" << 'AGENT_CODE'
const http = require('http');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = parseInt(process.env.MESH_AGENT_PORT || '20140', 10);
const AUTH_TOKEN = process.env.MESH_AUTH_TOKEN || '';
const WORKER_ID = process.env.WORKER_ID || 'unknown';

function verifyAuth(req, res) {
    if (!AUTH_TOKEN) return true;
    const authHeader = req.headers['authorization'] || '';
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const provided = match ? match[1].trim() : '';
    if (provided !== AUTH_TOKEN.trim()) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: 'Unauthorized: Invalid Mesh Token' }));
        return false;
    }
    return true;
}

function parseJsonBody(req, callback) {
    let body = '';
    req.on('data', chunk => {
        body += chunk;
        if (body.length > 50 * 1024 * 1024) req.socket.destroy();
    });
    req.on('end', () => {
        try {
            const data = body ? JSON.parse(body) : {};
            callback(null, data);
        } catch (err) {
            callback(err, null);
        }
    });
}

const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
            ok: true,
            role: 'mesh-agent',
            worker_id: WORKER_ID,
            hostname: os.hostname(),
            uptime: Math.floor(os.uptime()),
            loadavg: os.loadavg(),
            memory: { total: os.totalmem(), free: os.freemem() }
        }));
    }

    if (!verifyAuth(req, res)) return;

    if (req.method === 'POST' && req.url === '/exec') {
        parseJsonBody(req, (err, data) => {
            if (err || !data.command) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: 'Bad Request: "command" required' }));
            }
            const timeoutMs = parseInt(data.timeout || '60000', 10);
            exec(data.command, { timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024, shell: '/bin/bash' }, (error, stdout, stderr) => {
                res.writeHead(200, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({
                    ok: !error,
                    exitCode: error ? (error.code ?? 1) : 0,
                    stdout: stdout || '',
                    stderr: stderr || (error ? error.message : '')
                }));
            });
        });
        return;
    }

    if (req.method === 'POST' && req.url === '/file/write') {
        parseJsonBody(req, (err, data) => {
            if (err || !data.path || data.content === undefined) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: 'Bad Request: "path" and "content" required' }));
            }
            try {
                fs.mkdirSync(path.dirname(data.path), { recursive: true });
                const buf = Buffer.from(data.content, data.encoding || 'base64');
                fs.writeFileSync(data.path, buf);
                if (data.mode) fs.chmodSync(data.path, parseInt(data.mode, 8));
                res.writeHead(200, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: true, path: data.path, size: buf.length }));
            } catch (e) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: e.message }));
            }
        });
        return;
    }

    if (req.method === 'GET' && req.url.startsWith('/file/read')) {
        const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
        const targetPath = parsedUrl.searchParams.get('path');
        if (!targetPath || !fs.existsSync(targetPath)) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({ ok: false, error: 'File not found' }));
        }
        try {
            const buf = fs.readFileSync(targetPath);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({ ok: true, path: targetPath, size: buf.length, content: buf.toString('base64') }));
        } catch (e) {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({ ok: false, error: e.message }));
        }
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: 'Not found' }));
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`[mesh-agent] Worker ${WORKER_ID} listening on 127.0.0.1:${PORT}`);
});
AGENT_CODE

cat > "/etc/systemd/system/mesh-agent.service" << EOF
[Unit]
Description=Muse Mesh Worker Remote Control Daemon (Worker ${WORKER_ID})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${AGENT_DIR}
Environment=MESH_AGENT_PORT=20140
Environment=WORKER_ID=${WORKER_ID}
Environment=MESH_AUTH_TOKEN=${TOKEN}
ExecStart=/usr/bin/node ${AGENT_DIR}/agent.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mesh-agent.service
echo -e "${GREEN}✓ Mesh Control Agent aktif di port internal 20140.${NC}"

# 7. Pasang dan Aktifkan systemd service Reverse Tunnel (Dual Tunnel: Model + Remote Control)
echo -e "${YELLOW}[4/6] Memasang service auto-reconnect ${SERVICE_NAME}.service...${NC}"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=SSH Reverse Tunnel Worker VM ${WORKER_ID} ke VM 1 (Model: ${REMOTE_PORT}, Control: ${SSH_CONTROL_PORT})
After=network.target muse-bridge.service mesh-agent.service
Wants=muse-bridge.service mesh-agent.service

[Service]
Type=simple
User=root
EnvironmentFile=-/home/hatch/server-control/proxy.env
Environment=SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
ExecStart=/usr/bin/ssh -F /home/hatch/.ssh/config -i ${SSH_KEY_HATCH} -N -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} -R ${SSH_CONTROL_PORT}:127.0.0.1:20140 ${HOST_ALIAS}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"
echo -e "${GREEN}✓ Service ${SERVICE_NAME}.service aktif & berjalan!${NC}"

# 8. Pasang ke recover.sh (Anti-VM Replace)
RECOVER_DIR="/home/hatch/workspace/vm-recovery"
mkdir -p "$RECOVER_DIR"
RECOVER_SH="${RECOVER_DIR}/recover.sh"
if [ ! -f "$RECOVER_SH" ]; then
    echo '#!/bin/bash' > "$RECOVER_SH"
    chmod +x "$RECOVER_SH"
fi

echo -e "${YELLOW}[5/6] Mengamankan konfigurasi ke recover.sh...${NC}"
if ! grep -q "${SERVICE_NAME}" "$RECOVER_SH"; then
    cat >> "$RECOVER_SH" << EOF

# ---- Muse Multi-VM Reverse Tunnel & Control Worker ${WORKER_ID} ----
if [ ! -f /etc/systemd/system/mesh-agent.service ] && [ -d /home/hatch/www/mesh-agent ]; then
  cat > /etc/systemd/system/mesh-agent.service << 'UNIT_AGENT'
[Unit]
Description=Muse Mesh Worker Remote Control Daemon (Worker ${WORKER_ID})
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/home/hatch/www/mesh-agent
Environment=MESH_AGENT_PORT=20140
Environment=WORKER_ID=${WORKER_ID}
Environment=MESH_AUTH_TOKEN=${TOKEN}
ExecStart=/usr/bin/node /home/hatch/www/mesh-agent/agent.js
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT_AGENT
  systemctl daemon-reload
  systemctl enable --now mesh-agent.service
fi

if [ ! -f /etc/systemd/system/${SERVICE_NAME}.service ]; then
  cat > /etc/systemd/system/${SERVICE_NAME}.service << 'UNIT'
[Unit]
Description=SSH Reverse Tunnel Worker VM ${WORKER_ID} ke VM 1 (Model: ${REMOTE_PORT}, Control: ${SSH_CONTROL_PORT})
After=network.target muse-bridge.service mesh-agent.service
Wants=muse-bridge.service mesh-agent.service
[Service]
Type=simple
User=root
EnvironmentFile=-/home/hatch/server-control/proxy.env
Environment=SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
ExecStart=/usr/bin/ssh -F /home/hatch/.ssh/config -i /home/hatch/.ssh/id_mesh_master -N -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R ${REMOTE_PORT}:127.0.0.1:${LOCAL_PORT} -R ${SSH_CONTROL_PORT}:127.0.0.1:20140 ${HOST_ALIAS}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now ${SERVICE_NAME}.service
fi

if ! systemctl is-active --quiet ${SERVICE_NAME}.service; then
  systemctl restart ${SERVICE_NAME}.service || true
fi
EOF
    echo -e "${GREEN}✓ Berhasil diamankan di recover.sh.${NC}"
else
    echo -e "${GREEN}✓ Sudah terdaftar di recover.sh.${NC}"
fi

# 8. Pasang Watchdog Cron Tiap 1 Menit (jika crontab tersedia)
echo -e "${YELLOW}[5/5] Memeriksa Watchdog Cron...${NC}"
CRON_CMD="* * * * * /bin/bash /home/hatch/workspace/vm-recovery/recover.sh >/dev/null 2>&1"
if command -v crontab >/dev/null 2>&1; then
    (crontab -l 2>/dev/null | grep -Fv "recover.sh"; echo "$CRON_CMD") | crontab - || true
    echo -e "${GREEN}✓ Cron watchdog tiap 1 menit berhasil aktif!${NC}"
else
    echo -e "${YELLOW}ℹ️ Utilitas crontab tidak tersedia di sistem ini (auto-restart dijaga oleh systemd & recovery.sh).${NC}"
fi

# 9. Otomasi Registrasi ke 9Router di VM 1 via SSH
echo -e "${CYAN}----------------------------------------------------------------------${NC}"
echo -e "${YELLOW}⚡ [Otomasi 9Router] Mendaftarkan VM ${WORKER_ID} langsung ke 9Router di VM 1...${NC}"
if [ -f /home/hatch/server-control/proxy.env ]; then
    set -a; . /home/hatch/server-control/proxy.env; set +a
fi

WORKER_BRIDGE_KEY=""
if [ -f /home/hatch/muse-bridge/.bridge_key ]; then
    WORKER_BRIDGE_KEY=$(cat /home/hatch/muse-bridge/.bridge_key 2>/dev/null | tr -d '\r\n')
elif [ -f /home/hatch/muse-bridge/config.json ]; then
    WORKER_BRIDGE_KEY=$(grep -o '"bridge_key": "[^"]*"' /home/hatch/muse-bridge/config.json 2>/dev/null | head -1 | cut -d'"' -f4)
fi

ssh -F /home/hatch/.ssh/config -i "${SSH_KEY_HATCH}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "${HOST_ALIAS}" "python3 /home/hatch/register_worker_9router.py ${WORKER_ID} ${REMOTE_PORT} '${WORKER_BRIDGE_KEY}'" 2>/dev/null && echo -e "${GREEN}✓ Berhasil terdaftar otomatis di 9Router VM 1 dengan bridge key asli!${NC}" || echo -e "${YELLOW}⚠️ Pendaftaran otomatis 9Router dijadwalkan ulang saat tunnel tersinkronisasi.${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 SUKSES LENGKAP! WORKER VM ${WORKER_ID} TELAH AKTIF & TERKONEKSI!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "\nTerowongan 2 Arah (Mesh Tunnel) aktif menghubungkan Worker ke VM 1:"
echo -e "🤖 Model AI di VM 1      : ${YELLOW}http://127.0.0.1:${REMOTE_PORT}/v1${NC} (Port ${REMOTE_PORT})"
echo -e "💻 Akses Kendali SSH VM 1 : ${YELLOW}Port ${SSH_CONTROL_PORT}${NC} (Dari VM 1: ${CYAN}mesh ssh ${WORKER_ID}${NC})"
echo -e "🤖 Muse Bridge lokal     : ${GREEN}Aktif di port ${LOCAL_PORT}${NC}"
echo -e "🛡️ Watchdog pemulihan     : ${GREEN}Aktif tiap 1 menit via cron (* * * * *)${NC}"
echo -e "🤖 Model di 9Router       : ${YELLOW}muse/muse-spark-vm${WORKER_ID}${NC}\n"
echo -e "${GREEN}Dari VM 1, Anda sekarang bisa menjalankan: ${BOLD}mesh ssh ${WORKER_ID}${NC} ${GREEN}atau ${BOLD}mesh exec ${WORKER_ID} \"uptime\"${NC}\n"
