# 🌐 Muse Multi-VM Mesh Tunnel

Hubungkan banyak VM Worker AI ke satu pusat gateway **9Router** secara otomatis dalam 2 langkah mudah.

---

### 📋 Syarat di Server Utama (VM 1):
Pastikan di VM 1 sudah ada:
1. ✅ **9Router** sudah terpasang & berjalan (port 20128).
2. ✅ **Akses SSH** aktif (bisa via IP publik atau Cloudflare Tunnel `ssh.domainanda.com`).
3. ✅ **Akses Root** (akun root/sudo).

---

## ⚡ Cara Pakai (Hanya 2 Langkah)

### 1️⃣ Di Server Utama (VM 1 - Hub 9Router)
Jalankan perintah ini di terminal server utama:
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
```
> 👉 **Salin teks TOKEN yang muncul di layar terminal.**

---

### 2️⃣ Di VM Worker Baru (VM 2, VM 3, dst.)
Jalankan perintah ini di terminal worker baru:
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash
```
> Ketik nomor worker (misal `2`), domain SSH Anda, lalu tempelkan **TOKEN** dari Langkah 1.

---

### 🎉 Selesai!
- 🤖 **AI Muse Bridge** otomatis dipasang & diaktifkan di worker.
- 🔗 **Terowongan Tunnel** langsung tersambung otomatis ke 9Router.
- 🛡️ **Otomatis Pulih** sendiri dalam 1 menit jika koneksi putus atau VM di-restart.

---

## 📄 Lisensi
MIT License © 2026 bluudzz
