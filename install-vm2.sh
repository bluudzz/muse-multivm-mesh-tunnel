#!/bin/bash
# ==============================================================================
# INSTALL-VM2.SH — Installer Cepat untuk VM 2 (Worker 2)
# Repositori: https://github.com/bluudzz/muse-multivm-mesh-tunnel
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${SCRIPT_DIR}/install-worker.sh"
exec "${SCRIPT_DIR}/install-worker.sh" 2 "$@"
