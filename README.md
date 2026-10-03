# 🌐 Muse Multi-VM Mesh Tunnel & 9Router Hub

Sistem otomatisasi penuh untuk menghubungkan beberapa instans **VM Muse Spark (Hatch Runtime)** ke satu pusat gateway **9Router** menggunakan metode **SSH Reverse Tunnel** yang dilindungi oleh **Cloudflare Access**.

---

## ⚡ PANDUAN CEPAT (HANYA 2 LANGKAH)

```
[1. VM Utama (VM 1)]                 [2. VM Worker (VM 2, 3, dst.)]
Jalankan setup-hub.sh ──► Dapat Token ──► Jalankan setup-worker.sh ──► SELESAI!
```

---

### 1️⃣ LANGKAH 1: Di VM Utama (VM 1 - Central Hub)

Buka terminal di **VM 1**, lalu jalankan perintah ini:

```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
```

**Apa yang terjadi?**
- Skrip otomatis menyiapkan folder SSH, membuat **Kunci Induk (Master Mesh Key)**, memasang gembok ke `authorized_keys` (root & hatch), dan mengamankannya ke `recover.sh` (anti-VM replace).
- Di akhir eksekusi, terminal akan menampilkan **KOTAK TOKEN BESAR**:

```text
======================================================================
🔑 SALIN TOKEN KUNCI INDUK DI BAWAH INI:
----------------------------------------------------------------------
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbG...
----------------------------------------------------------------------
```
👉 **Salin token teks tersebut.** Token ini adalah anak kunci yang Anda gunakan untuk mengaktifkan semua VM Worker berikutnya.

---

### 2️⃣ LANGKAH 2: Di VM Worker Baru (VM 2, VM 3, VM 4, dst.)

Buka terminal di VM Worker baru mana pun, lalu cukup jalankan perintah interaktif ini:

```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash
```

**Terminal akan menanyakan 3 hal:**
1. **Nomor Worker** (misal: `2` untuk VM 2, `3` untuk VM 3)
2. **Hostname SSH Hub VM 1** (misal: `ssh.yourdomain.com`)
3. **Token Kunci Induk** (yang didapat dari Langkah 1)

*(Atau jalankan langsung dengan parameter tanpa tanya-jawab:)*
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 2 "PASTE_TOKEN_DISINI" "ssh.yourdomain.com"
```

> 🎉 **Selesai!** Muse Bridge otomatis diinstal & diaktifkan di port 20129, terowongan langsung tersambung ke port `20130` di VM 1, dan otomatis didaftarkan ke 9Router!

---

## 📊 Pemetaan Port & Model di 9Router (VM 1)

Setiap worker otomatis mendapatkan port forward mandiri di VM 1:

| Worker Node | Perintah di Worker | Port Lokal di VM 1 | Model ID di 9Router |
|---|---|---|---|
| **VM 1** | `setup-hub.sh` | Port 20128 | Gateway 9Router Utama |
| **VM 2** | `setup-worker.sh 2` | **`20130`** | `muse/muse-spark-vm2` |
| **VM 3** | `setup-worker.sh 3` | **`20131`** | `muse/muse-spark-vm3` |
| **VM 4** | `setup-worker.sh 4` | **`20132`** | `muse/muse-spark-vm4` |
| **VM $N$** | `setup-worker.sh N` | **`20128 + N`** | `muse/muse-spark-vmN` |

---

## 📌 Cara Cek Provider di Dashboard 9Router

Setelah worker terhubung:
1. Buka dashboard web 9Router di VM 1:  
   👉 **`https://9router.yourdomain.com/ui`** (atau `http://127.0.0.1:20128/ui`)
2. Masuk ke menu **Providers**:
   Provider worker akan otomatis terdaftar dan berstatus **Connected**.
3. Klik tombol **Chat** untuk langsung menguji respon AI dari worker terkait!

---

## 🛡️ Fitur Anti "VM Replace" (Pemulihan Otomatis)

Semua skrip di repositori ini mematuhi standar Hatch Runtime:
- Semua konfigurasi disimpan di dalam `/home/hatch/`.
- Setiap service otomatis didaftarkan ke `/home/hatch/workspace/vm-recovery/recover.sh`.
- Dilengkapi **Watchdog Cron Tiap 1 Menit** yang otomatis memantau dan menghidupkan kembali service jika terputus.
- Jika VM di-replace atau di-restart oleh provider, seluruh koneksi tunnel dan otorisasi SSH akan **pulih otomatis secara mandiri tanpa campur tangan manusia**.

---

## 📄 Lisensi
MIT License © 2026 bluudzz
