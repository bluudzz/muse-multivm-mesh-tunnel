#!/bin/bash
# ==============================================================================
# MESH-CTL.SH — Central Orchestration & Control CLI for Muse Multi-VM Mesh
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# Perintah cepat: mesh <list|ssh|exec|push|pull|restart|status>
# Mendukung Mesh Control Agent (Node.js) & Fallback OpenSSH
# ==============================================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
GRAY='\033[0;90m'
NC='\033[0m'

KEY_HATCH="/home/hatch/.ssh/id_mesh_master"
KEY_ROOT="/root/.ssh/id_mesh_master"

if [ -f "$KEY_HATCH" ]; then
    SSH_KEY="$KEY_HATCH"
elif [ -f "$KEY_ROOT" ]; then
    SSH_KEY="$KEY_ROOT"
else
    SSH_KEY="$HOME/.ssh/id_mesh_master"
fi

TOKEN=""
if [ -f "$SSH_KEY" ]; then
    TOKEN=$(base64 -w 0 "$SSH_KEY" 2>/dev/null || base64 "$SSH_KEY" 2>/dev/null | tr -d '\r\n')
fi

get_ssh_port() {
    local id="$1"
    echo $(( 22000 + id ))
}

get_model_port() {
    local id="$1"
    echo $(( 20128 + id ))
}

is_port_open() {
    local port="$1"
    if ss -tln 2>/dev/null | grep -q ":${port} "; then
        return 0
    elif netstat -tln 2>/dev/null | grep -q ":${port} "; then
        return 0
    fi
    return 1
}

is_agent_open() {
    local port="$1"
    if curl -s -m 2 --noproxy '*' "http://127.0.0.1:${port}/health" 2>/dev/null | grep -q '"role":"mesh-agent"'; then
        return 0
    fi
    return 1
}

agent_exec() {
    local port="$1"
    local cmd="$2"

    local auth_header=""
    if [ -n "$TOKEN" ]; then
        auth_header="Authorization: Bearer ${TOKEN}"
    fi

    # Buat JSON payload dengan python jika tersedia, fallback ke printf
    local payload
    if command -v python3 >/dev/null 2>&1; then
        payload=$(python3 -c "import json, sys; print(json.dumps({'command': sys.argv[1]}))" "$cmd")
    else
        local escaped=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        payload="{\"command\":\"$escaped\"}"
    fi

    local resp
    resp=$(curl -s -m 60 --noproxy '*' \
        -H "Content-Type: application/json" \
        ${auth_header:+-H "$auth_header"} \
        -d "$payload" \
        "http://127.0.0.1:${port}/exec" 2>/dev/null || echo '{"ok":false,"error":"Connection failed"}')

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
try:
    d = json.loads('''$resp''')
    if d.get('stdout'):
        sys.stdout.write(d['stdout'])
    if d.get('stderr'):
        sys.stderr.write(d['stderr'])
    sys.exit(d.get('exitCode', 0 if d.get('ok') else 1))
except Exception:
    print('''$resp''')
    sys.exit(1)
"
    else
        echo "$resp"
    fi
}

find_active_workers() {
    local active=""
    for id in {2..25}; do
        local sp=$(get_ssh_port "$id")
        local mp=$(get_model_port "$id")
        if is_port_open "$sp" || is_port_open "$mp"; then
            active="${active} ${id}"
        fi
    done
    echo "$active"
}

cmd_list() {
    echo -e "\n${CYAN}================================================================================${NC}"
    echo -e "${CYAN}${BOLD}              🌐 MUSE MULTI-VM MESH: DAFTAR WORKER NODE TERHUBUNG               ${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    printf "%-8s %-12s %-12s %-18s %-18s %s\n" "NODE" "CONTROL PORT" "MODEL PORT" "CONTROL STATUS" "MUSE BRIDGE" "UPTIME / INFO"
    echo -e "${GRAY}--------------------------------------------------------------------------------${NC}"

    local count=0
    for id in {2..25}; do
        local sp=$(get_ssh_port "$id")
        local mp=$(get_model_port "$id")
        local control_status="${GRAY}Offline${NC}"
        local muse_status="${GRAY}Offline${NC}"
        local info="-"

        local has_control=false
        local has_muse=false

        if is_agent_open "$sp"; then
            has_control=true
            control_status="${GREEN}ONLINE (Agent)${NC}"
            local upt
            upt=$(curl -s -m 2 --noproxy '*' "http://127.0.0.1:${sp}/health" 2>/dev/null | grep -o '"uptime":[0-9]*' | cut -d: -f2 || echo "")
            if [ -n "$upt" ]; then
                local mins=$(( upt / 60 ))
                local hours=$(( mins / 60 ))
                if [ "$hours" -gt 0 ]; then
                    info="${CYAN}up ${hours}h $(( mins % 60 ))m${NC}"
                else
                    info="${CYAN}up ${mins}m${NC}"
                fi
            fi
        elif is_port_open "$sp"; then
            has_control=true
            control_status="${YELLOW}PORT OPEN${NC}"
        fi

        if is_port_open "$mp"; then
            has_muse=true
            if curl -s --connect-timeout 1 -m 2 --noproxy '*' "http://127.0.0.1:${mp}/health" >/dev/null 2>&1; then
                muse_status="${GREEN}ACTIVE (200)${NC}"
            else
                muse_status="${YELLOW}LISTENING${NC}"
            fi
        fi

        if [ "$has_muse" = true ] && [ "$has_control" = false ]; then
            control_status="${GRAY}N/A (AI Node)${NC}"
        fi

        if [ "$has_control" = true ] || [ "$has_muse" = true ]; then
            count=$(( count + 1 ))

            if [ "$info" = "-" ] && [ "$has_muse" = true ]; then
                local model_name
                model_name=$(curl -s --connect-timeout 1 -m 2 --noproxy '*' "http://127.0.0.1:${mp}/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
                if [ -n "$model_name" ]; then
                    info="${CYAN}${model_name}${NC}"
                fi
            fi

            printf "%-8s %-12s %-12s %-27b %-27b %b\n" "VM ${id}" "${sp}" "${mp}" "${control_status}" "${muse_status}" "${info}"
        fi
    done

    echo -e "${GRAY}--------------------------------------------------------------------------------${NC}"
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}Tidak ada worker node yang sedang aktif.${NC}"
        echo -e "Jalankan skrip ${CYAN}setup-worker.sh${NC} di VM 2, VM 3, dst. untuk menghubungkan."
    else
        echo -e "${GREEN}Total node terdeteksi: ${count} worker node.${NC}"
    fi
    echo -e "${CYAN}================================================================================${NC}\n"
}

cmd_ssh() {
    local id="$1"
    if [ -z "$id" ]; then
        echo -e "${RED}Error: Masukkan ID worker! Contoh: mesh ssh 2${NC}"
        exit 1
    fi

    local port=$(get_ssh_port "$id")
    local mp=$(get_model_port "$id")

    if is_agent_open "$port"; then
        echo -e "\n${CYAN}======================================================================${NC}"
        echo -e "${GREEN}Terhubung ke Worker VM ${id} via Mesh Control Agent${NC}"
        echo -e "Ketik perintah bash langsung, atau ketik '${YELLOW}exit${NC}' untuk kembali ke VM 1."
        echo -e "${CYAN}======================================================================${NC}\n"

        while true; do
            read -e -p "[VM ${id}] root@mesh:# " input
            [ -z "$input" ] && continue
            if [ "$input" = "exit" ] || [ "$input" = "quit" ]; then
                echo -e "${YELLOW}Sesi kontrol VM ${id} ditutup.${NC}"
                break
            fi
            agent_exec "$port" "$input" || true
        done
        return 0
    elif is_port_open "$port"; then
        echo -e "${GREEN}Menghubungkan ke VM ${id} (Port ${port}) via SSH standar...${NC}"
        ssh -i "$SSH_KEY" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@127.0.0.1"
        return 0
    else
        if is_port_open "$mp"; then
            echo -e "${YELLOW}ℹ Worker VM ${id} beroperasi dalam mode 'AI Model Node' (tanpa Mesh Control Agent).${NC}"
            echo -e "Model AI aktif & dapat diakses via 9Router (Port ${mp})."
            echo -e "Untuk mengaktifkan remote control, jalankan skrip setup-worker.sh terbaru di VM ${id}."
            exit 0
        fi
        echo -e "${RED}Error: Port kendali ${port} untuk VM ${id} tidak aktif.${NC}"
        exit 1
    fi
}

cmd_exec() {
    local target="$1"
    shift
    local cmd="$*"

    if [ -z "$target" ] || [ -z "$cmd" ]; then
        echo -e "${RED}Error: Parameter tidak lengkap!${NC}"
        echo -e "Penggunaan: mesh exec <ID|all> \"<perintah>\""
        echo -e "Contoh    : mesh exec 2 \"cat /etc/os-release\""
        echo -e "Contoh    : mesh exec all \"uptime\""
        exit 1
    fi

    if [ "$target" = "all" ]; then
        local workers=$(find_active_workers)
        if [ -z "$workers" ]; then
            echo -e "${YELLOW}Tidak ada worker yang aktif saat ini.${NC}"
            exit 0
        fi

        echo -e "\n${CYAN}======================================================================${NC}"
        echo -e "${CYAN}⚡ Menjalankan perintah serentak ke semua worker: ${YELLOW}${cmd}${NC}"
        echo -e "${CYAN}======================================================================${NC}\n"

        for id in $workers; do
            local port=$(get_ssh_port "$id")
            if is_agent_open "$port"; then
                echo -e "${GREEN}─── [VM ${id}] (Agent Port ${port}) ───${NC}"
                agent_exec "$port" "$cmd" || echo -e "${RED}Gagal mengeksekusi di VM ${id}${NC}"
                echo ""
            elif is_port_open "$port"; then
                echo -e "${GREEN}─── [VM ${id}] (SSH Port ${port}) ───${NC}"
                ssh -i "$SSH_KEY" -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 "$cmd" 2>&1 || echo -e "${RED}Gagal mengeksekusi di VM ${id}${NC}"
                echo ""
            fi
        done
    else
        local port=$(get_ssh_port "$target")
        local mp=$(get_model_port "$target")

        if is_agent_open "$port"; then
            echo -e "${GREEN}[VM ${target}] Eksekusi via Agent: ${YELLOW}${cmd}${NC}\n"
            agent_exec "$port" "$cmd"
        elif is_port_open "$port"; then
            echo -e "${GREEN}[VM ${target}] Eksekusi via SSH: ${YELLOW}${cmd}${NC}\n"
            ssh -i "$SSH_KEY" -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 "$cmd"
        else
            if is_port_open "$mp"; then
                echo -e "${YELLOW}ℹ Worker VM ${target} terhubung sebagai AI Model Node (tanpa Control Agent).${NC}"
                echo -e "Model AI aktif & melayani inferensi via 9Router (Port ${mp})."
                echo -e "Untuk mengaktifkan kendali remote, update setup-worker.sh di VM ${target}."
                exit 0
            fi
            echo -e "${RED}Error: VM ${target} (Port ${port}) tidak aktif.${NC}"
            exit 1
        fi
    fi
}

cmd_push() {
    local target="$1"
    local local_path="$2"
    local remote_path="$3"

    if [ -z "$target" ] || [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        echo -e "${RED}Penggunaan: mesh push <ID> <local_path> <remote_path>${NC}"
        echo -e "Contoh    : mesh push 2 ./script.sh /home/hatch/script.sh"
        exit 1
    fi

    if [ ! -f "$local_path" ]; then
        echo -e "${RED}Error: File lokal '$local_path' tidak ditemukan!${NC}"
        exit 1
    fi

    local port=$(get_ssh_port "$target")
    if is_agent_open "$port"; then
        echo -e "${CYAN}Mengirim file ke VM ${target} via Mesh Agent...${NC}"
        local b64
        b64=$(base64 -w 0 "$local_path" 2>/dev/null || base64 "$local_path" | tr -d '\r\n')

        local payload
        if command -v python3 >/dev/null 2>&1; then
            payload=$(python3 -c "import json; print(json.dumps({'path': '$remote_path', 'content': '$b64'}))")
        else
            payload="{\"path\":\"$remote_path\",\"content\":\"$b64\"}"
        fi

        local auth_header=""
        [ -n "$TOKEN" ] && auth_header="Authorization: Bearer ${TOKEN}"

        local resp
        resp=$(curl -s -m 60 --noproxy '*' \
            -H "Content-Type: application/json" \
            ${auth_header:+-H "$auth_header"} \
            -d "$payload" \
            "http://127.0.0.1:${port}/file/write" 2>/dev/null || echo '{"ok":false}')

        if echo "$resp" | grep -q '"ok":true'; then
            echo -e "${GREEN}✓ File berhasil terkirim ke VM ${target} ($remote_path)!${NC}"
        else
            echo -e "${RED}Gagal mengirim file: $resp${NC}"
            exit 1
        fi
    elif is_port_open "$port"; then
        echo -e "${CYAN}Mengirim ke VM ${target} via SCP...${NC}"
        scp -i "$SSH_KEY" -P "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$local_path" "root@127.0.0.1:${remote_path}"
        echo -e "${GREEN}✓ Berhasil terkirim ke VM ${target}!${NC}"
    else
        echo -e "${RED}Error: VM ${target} port kendali tidak aktif.${NC}"
        exit 1
    fi
}

cmd_pull() {
    local id="$1"
    local remote_path="$2"
    local local_path="$3"

    if [ -z "$id" ] || [ -z "$remote_path" ] || [ -z "$local_path" ]; then
        echo -e "${RED}Penggunaan: mesh pull <ID> <remote_path> <local_path>${NC}"
        echo -e "Contoh    : mesh pull 2 /home/hatch/backup.tar.gz ./backup.tar.gz"
        exit 1
    fi

    local port=$(get_ssh_port "$id")
    if is_agent_open "$port"; then
        echo -e "${CYAN}Mengunduh file dari VM ${id} via Mesh Agent...${NC}"
        local auth_header=""
        [ -n "$TOKEN" ] && auth_header="Authorization: Bearer ${TOKEN}"

        local encoded_path
        encoded_path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$remote_path'))" 2>/dev/null || echo "$remote_path")

        local resp
        resp=$(curl -s -m 60 --noproxy '*' \
            ${auth_header:+-H "$auth_header"} \
            "http://127.0.0.1:${port}/file/read?path=${encoded_path}" 2>/dev/null || echo '{"ok":false}')

        if echo "$resp" | grep -q '"ok":true'; then
            python3 -c "
import json, base64
d = json.loads('''$resp''')
with open('$local_path', 'wb') as f:
    f.write(base64.b64decode(d['content']))
"
            echo -e "${GREEN}✓ File berhasil diunduh ke $local_path!${NC}"
        else
            echo -e "${RED}Gagal mengunduh file: $resp${NC}"
            exit 1
        fi
    elif is_port_open "$port"; then
        scp -i "$SSH_KEY" -P "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@127.0.0.1:${remote_path}" "$local_path"
        echo -e "${GREEN}✓ File berhasil diunduh dari VM ${id}!${NC}"
    else
        echo -e "${RED}Error: VM ${id} port kendali tidak aktif.${NC}"
        exit 1
    fi
}

cmd_restart() {
    local target="$1"
    local service="${2:-muse-bridge}"

    if [ -z "$target" ]; then
        echo -e "${RED}Penggunaan: mesh restart <ID|all> [service_name]${NC}"
        echo -e "Contoh    : mesh restart 2 muse-bridge"
        exit 1
    fi

    cmd_exec "$target" "systemctl restart ${service} && systemctl status ${service} --no-pager -n 5"
}

cmd_help() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN}${BOLD}       🌐 MUSE MESH CONTROL CLI — Central Master Orchestrator          ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "Utility untuk mengendalikan & memonitor seluruh VM worker dari VM 1.\n"
    echo -e "${YELLOW}Perintah Tersedia:${NC}"
    echo -e "  ${GREEN}mesh list${NC}                     Tampilkan status semua worker (Control & Model)"
    echo -e "  ${GREEN}mesh status${NC}                   Alias untuk 'mesh list'"
    echo -e "  ${GREEN}mesh ssh <ID>${NC}                 Buka shell interaktif ke worker via Mesh Agent"
    echo -e "  ${GREEN}mesh exec <ID|all> \"<cmd>\"${NC}   Jalankan perintah bash di worker tertentu/semua"
    echo -e "  ${GREEN}mesh push <ID> <src> <dst>${NC}    Kirim file dari VM 1 ke worker"
    echo -e "  ${GREEN}mesh pull <ID> <remote> <lokal>${NC} Unduh file dari worker ke VM 1"
    echo -e "  ${GREEN}mesh restart <ID|all> [svc]${NC}   Restart systemd service di worker (default: muse-bridge)"
    echo -e "  ${GREEN}mesh help${NC}                     Tampilkan bantuan ini\n"
    echo -e "${YELLOW}Contoh Pemakaian:${NC}"
    echo -e "  mesh list"
    echo -e "  mesh ssh 2"
    echo -e "  mesh exec 2 \"df -h\""
    echo -e "  mesh exec 3 \"systemctl restart muse-bridge\""
    echo -e "  mesh exec all \"uptime\""
    echo -e "  mesh restart all muse-bridge"
    echo -e "  mesh push 2 ./config.json /home/hatch/config.json\n"
}

case "${1:-list}" in
    list|status|ls)
        cmd_list
        ;;
    ssh|connect)
        shift
        cmd_ssh "$@"
        ;;
    exec|run|cmd)
        shift
        cmd_exec "$@"
        ;;
    push|send|upload)
        shift
        cmd_push "$@"
        ;;
    pull|get|download)
        shift
        cmd_pull "$@"
        ;;
    restart)
        shift
        cmd_restart "$@"
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        cmd_help
        ;;
esac
