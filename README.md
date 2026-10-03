# 🌐 Muse Multi-VM Mesh Tunnel & 9Router Hub

> **Solusi 1-Klik Zero-Touch** untuk menghubungkan banyak VM AI Worker ke satu gateway pusat **9Router** menggunakan **SSH Reverse Tunnel** yang aman, otomatis pulih, dan tahan banting.

---

### ✨ Apa yang Dilakukan Alat Ini?
- 🔗 **Menghubungkan VM Tanpa IP Publik**: Worker VM bisa berada di mana saja (NAT, VPS kecil, sandbox) tanpa perlu buka port atau sewa domain baru.
- 🤖 **Auto-Install AI Bridge**: Otomatis memasang dan menjalankan `muse-bridge` di worker.
- ⚡ **Auto-Register 9Router**: Worker otomatis mendaftarkan dirinya sendiri ke dashboard 9Router di server utama.
- 🛡️ **Watchdog 1-Menit (Anti-Rontok)**: Memeriksa koneksi tiap 60 detik. Jika putus atau VM di-replace/restart oleh provider, sistem akan otomatis pulih sendiri!

---

## 🚀 Panduan Cepat (Hanya 2 Langkah)

```
[1. VM Utama (Hub)]                  [2. VM Worker Baru]
Jalankan setup-hub.sh ──► Dapat Token ──► Jalankan setup-worker.sh ──► SELESAI!
```

---

### 1️⃣ Langkah 1: Di Server Utama (VM 1 - Hub 9Router)

Buka terminal di server utama Anda, lalu salin dan jalankan perintah ini:

```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
```

Terminal akan menyiapkan kunci keamanan dan mencetak **KOTAK TOKEN**:
```text
======================================================================
🔑 SALIN TOKEN KUNCI INDUK DI BAWAH INI:
----------------------------------------------------------------------
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbG...
----------------------------------------------------------------------
```
👉 **Salin token teks tersebut.** Anda akan menggunakannya di setiap VM Worker baru.

---

### 2️⃣ Langkah 2: Di VM Worker Baru (VM 2, VM 3, dst.)

Buka terminal di VM Worker mana pun, lalu cukup jalankan perintah ini:

```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash
```

**Terminal akan menanyakan 3 hal mudah:**
1. **Nomor Worker:** Ketik `2` (untuk VM 2), `3` (untuk VM 3), dst.
2. **Domain SSH Hub:** Masukkan alamat SSH server utama Anda (contoh: `ssh.domainanda.com`).
3. **Token Kunci:** Tempelkan token yang Anda salin dari Langkah 1.

*(💡 Ingin langsung tanpa tanya jawab? Tambahkan parameternya langsung):*
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 2 "TOKEN_ANDA" "ssh.domainanda.com"
```

---

### 🎉 Selesai! Apa yang Terjadi Otomatis?
1. `muse-bridge` otomatis terpasang dan aktif di port lokal worker (`20129`).
2. Terowongan Reverse SSH langsung membuka port khusus di server utama:
   - **VM 2** ➔ Port **`20130`**
   - **VM 3** ➔ Port **`20131`**
   - **VM 4** ➔ Port **`20132`** *(dan seterusnya)*.
3. Worker **otomatis terdaftar ke 9Router** di server utama.
4. Anda bisa langsung membuka dashboard 9Router Anda (`https://9router.domainanda.com/ui`), klik tombol **Chat**, dan AI worker siap digunakan!

---

## 🛡️ Tahan Restart & VM Replacement (Self-Healing)
Jika Anda menggunakan penyedia VPS/sandbox yang sering me-replace sistem (seperti Hatch Runtime):
- Konfigurasi otomatis diamankan ke `/home/hatch/workspace/vm-recovery/recover.sh`.
- Dilengkapi **Cron Watchdog tiap 1 menit** (`* * * * *`). Jika koneksi putus atau VM baru selesai reboot, sistem otomatis menyambung kembali dalam waktu kurang dari 60 detik tanpa perlu tindakan manual.

---

## 📄 Lisensi
MIT License © 2026 bluudzz — Bebas digunakan dan dimodifikasi untuk kebutuhan komunitas.
