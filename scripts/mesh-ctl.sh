#!/bin/bash
# ==============================================================================
# MESH-CTL.SH — Central Orchestration & Control CLI for Muse Multi-VM Mesh
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# Perintah cepat: mesh <list|ssh|exec|push|pull|restart|status>
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
    printf "%-8s %-12s %-12s %-16s %-18s %s\n" "NODE" "SSH PORT" "MODEL PORT" "SSH STATUS" "MUSE BRIDGE" "UPTIME / INFO"
    echo -e "${GRAY}--------------------------------------------------------------------------------${NC}"

    local count=0
    for id in {2..25}; do
        local sp=$(get_ssh_port "$id")
        local mp=$(get_model_port "$id")
        local ssh_status="${GRAY}Offline${NC}"
        local muse_status="${GRAY}Offline${NC}"
        local info="-"

        local has_ssh=false
        local has_muse=false

        if is_port_open "$sp"; then
            has_ssh=true
            ssh_status="${GREEN}ONLINE${NC}"
        fi

        if is_port_open "$mp"; then
            has_muse=true
            if curl -s --connect-timeout 1 -m 2 --noproxy '*' "http://127.0.0.1:${mp}/health" >/dev/null 2>&1; then
                muse_status="${GREEN}ACTIVE (200)${NC}"
            else
                muse_status="${YELLOW}LISTENING${NC}"
            fi
        fi

        if [ "$has_muse" = true ] && [ "$has_ssh" = false ]; then
            ssh_status="${GRAY}N/A (AI Node)${NC}"
        fi

        if [ "$has_ssh" = true ] || [ "$has_muse" = true ]; then
            count=$(( count + 1 ))
            if [ "$has_ssh" = true ] && [ -f "$SSH_KEY" ]; then
                local res
                res=$(ssh -i "$SSH_KEY" -p "$sp" -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 "uptime -p 2>/dev/null || uptime | awk '{print \$3}'" 2>/dev/null | tr -d '\r\n' || echo "")
                if [ -n "$res" ]; then
                    info="${CYAN}${res}${NC}"
                fi
            fi

            if [ "$info" = "-" ] && [ "$has_muse" = true ]; then
                local model_name
                model_name=$(curl -s --connect-timeout 1 -m 2 --noproxy '*' "http://127.0.0.1:${mp}/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
                if [ -n "$model_name" ]; then
                    info="${CYAN}${model_name}${NC}"
                fi
            fi

            printf "%-8s %-12s %-12s %-25b %-27b %b\n" "VM ${id}" "${sp}" "${mp}" "${ssh_status}" "${muse_status}" "${info}"
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
    local user="${2:-root}"
    if [ -z "$id" ]; then
        echo -e "${RED}Error: Masukkan ID worker! Contoh: mesh ssh 2 [user]${NC}"
        exit 1
    fi

    local port=$(get_ssh_port "$id")
    local mp=$(get_model_port "$id")
    if ! is_port_open "$port"; then
        if is_port_open "$mp"; then
            echo -e "${YELLOW}ℹ Worker VM ${id} beroperasi dalam mode 'AI Model Node' (tanpa SSH Server).${NC}"
            echo -e "Model AI aktif & dapat diakses via 9Router (Port ${mp})."
            exit 0
        fi
        echo -e "${RED}Error: Port SSH ${port} untuk VM ${id} tidak terdeteksi listening.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Menghubungkan ke VM ${id} (127.0.0.1:${port}) sebagai user '${user}'...${NC}"
    ssh -i "$SSH_KEY" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${user}@127.0.0.1"
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
            if is_port_open "$port"; then
                echo -e "${GREEN}─── [VM ${id}] (Port ${port}) ───${NC}"
                ssh -i "$SSH_KEY" -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 "$cmd" 2>&1 || echo -e "${RED}Gagal mengeksekusi di VM ${id}${NC}"
                echo ""
            fi
        done
    else
        local port=$(get_ssh_port "$target")
        local mp=$(get_model_port "$target")
        if ! is_port_open "$port"; then
            if is_port_open "$mp"; then
                echo -e "${YELLOW}ℹ Worker VM ${target} terhubung sebagai AI Model Node (tanpa SSH Server).${NC}"
                echo -e "Model AI aktif & melayani inferensi via 9Router (Port ${mp})."
                exit 0
            fi
            echo -e "${RED}Error: VM ${target} (Port ${port}) tidak aktif.${NC}"
            exit 1
        fi
        echo -e "${GREEN}[VM ${target}] Eksekusi: ${YELLOW}${cmd}${NC}\n"
        ssh -i "$SSH_KEY" -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 "$cmd"
    fi
}

cmd_push() {
    local target="$1"
    local local_path="$2"
    local remote_path="$3"

    if [ -z "$target" ] || [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        echo -e "${RED}Penggunaan: mesh push <ID|all> <local_path> <remote_path>${NC}"
        echo -e "Contoh    : mesh push 2 ./script.sh /home/hatch/script.sh"
        exit 1
    fi

    if [ ! -e "$local_path" ]; then
        echo -e "${RED}Error: File lokal '$local_path' tidak ditemukan!${NC}"
        exit 1
    fi

    if [ "$target" = "all" ]; then
        local workers=$(find_active_workers)
        for id in $workers; do
            local port=$(get_ssh_port "$id")
            echo -e "${CYAN}Mengirim ke VM ${id}...${NC}"
            scp -i "$SSH_KEY" -P "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "$local_path" "root@127.0.0.1:${remote_path}"
        done
        echo -e "${GREEN}✓ Pengiriman ke seluruh worker selesai!${NC}"
    else
        local port=$(get_ssh_port "$target")
        echo -e "${CYAN}Mengirim ke VM ${target} (Port ${port})...${NC}"
        scp -i "$SSH_KEY" -P "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "$local_path" "root@127.0.0.1:${remote_path}"
        echo -e "${GREEN}✓ Berhasil terkirim ke VM ${target}!${NC}"
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
    echo -e "${CYAN}Mengambil file dari VM ${id} (Port ${port})...${NC}"
    scp -i "$SSH_KEY" -P "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "root@127.0.0.1:${remote_path}" "$local_path"
    echo -e "${GREEN}✓ File berhasil diunduh dari VM ${id}!${NC}"
}

cmd_restart() {
    local target="$1"
    local service="${2:-muse-bridge}"

    if [ -z "$target" ]; then
        echo -e "${RED}Penggunaan: mesh restart <ID|all> [service_name]${NC}"
        echo -e "Contoh    : mesh restart 2 muse-bridge"
        exit 1
    fi

    cmd_exec "$target" "systemctl restart ${service} && systemctl status ${service} --no-pager -n 3"
}

cmd_help() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${CYAN}${BOLD}       🌐 MUSE MESH CONTROL CLI — Central Master Orchestrator          ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "Utility untuk mengendalikan & memonitor seluruh VM worker dari VM 1.\n"
    echo -e "${YELLOW}Perintah Tersedia:${NC}"
    echo -e "  ${GREEN}mesh list${NC}                     Tampilkan status semua worker (SSH & Model)"
    echo -e "  ${GREEN}mesh status${NC}                   Alias untuk 'mesh list'"
    echo -e "  ${GREEN}mesh ssh <ID> [user]${NC}         Buka shell interaktif ke worker (default: root)"
    echo -e "  ${GREEN}mesh exec <ID|all> \"<cmd>\"${NC}   Jalankan perintah bash di worker tertentu/semua"
    echo -e "  ${GREEN}mesh push <ID|all> <src> <dst>${NC} Kirim file/folder dari VM 1 ke worker"
    echo -e "  ${GREEN}mesh pull <ID> <remote> <lokal>${NC} Unduh file dari worker ke VM 1"
    echo -e "  ${GREEN}mesh restart <ID|all> [svc]${NC}   Restart systemd service di worker (default: muse-bridge)"
    echo -e "  ${GREEN}mesh help${NC}                     Tampilkan bantuan ini\n"
    echo -e "${YELLOW}Contoh Pemakaian:${NC}"
    echo -e "  mesh list"
    echo -e "  mesh ssh 2"
    echo -e "  mesh exec 2 \"df -h\""
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
