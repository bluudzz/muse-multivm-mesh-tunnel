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

## 🤖 Alternatif: Menjalankan Lewat AI Agen di Masing-Masing VM

Jika VM Anda dikendalikan oleh AI Agent (seperti Muse, Hermes, atau asisten AI lokal), Anda tidak perlu mengetik perintah terminal secara manual. Cukup salin prompt berikut ke chat AI di masing-masing VM:

### 💬 Prompt untuk AI di Server Utama (VM 1 - Hub)
Salin & kirim ke AI di VM 1:
```text
Tolong siapkan server ini sebagai Hub Pusat (VM 1) untuk Muse Multi-VM Mesh Tunnel:
1. Pastikan port 20128 (9Router) dan OpenSSH server aktif.
2. Jalankan skrip setup resmi:
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
3. Setelah selesai, tampilkan teks MASTER TOKEN KUNCI INDUK yang dihasilkan dengan jelas agar bisa saya salin untuk VM worker berikutnya.
```

---

### 💬 Prompt untuk AI di VM Worker Baru (VM 2, VM 3, dst.)
Salin & kirim ke AI di VM Worker (AI akan bertanya terlebih dahulu sebelum bertindak):
```text
Tolong hubungkan VM ini sebagai Worker Node ke Hub Server Utama (VM 1) menggunakan Muse Mesh Tunnel.

⚠️ ATURAN WAJIB SEBELUM EKSEKUSI:
DILARANG menjalankan perintah apapun sebelum Anda menanyakan dan saya memberikan 3 data berikut:
1. Nomor Worker ID (contoh: 2, 3, 4, dst.)
2. Hostname / Domain SSH Hub VM 1 (contoh: ssh.domainanda.com atau IP publik)
3. Token Kunci Induk (Master Key Base64 dari setup VM 1)

Setelah saya menjawab dan memberikan ketiga data tersebut, jalankan perintah instalasi berikut:
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s -- --worker <NOMOR_WORKER> --host <SSH_HOST> --token "<MASTER_TOKEN>"

Kemudian periksa dan pastikan service muse-bridge dan reverse-tunnel berjalan normal.
```

---

## 📄 Lisensi
MIT License © 2026 bluudzz
