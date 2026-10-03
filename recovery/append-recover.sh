# ==============================================================================
# SNIPPET RECOVER.SH UNTUK VM 2
# Jalankan perintah ini di VM 2 untuk menambahkan auto-recovery ke recover.sh:
# cat recovery/append-recover.sh >> /home/hatch/workspace/vm-recovery/recover.sh
# ==============================================================================

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
