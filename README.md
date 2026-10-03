# 🌐 Muse Multi-VM Mesh Tunnel & 9Router Hub

Sistem otomatisasi untuk menghubungkan beberapa instans **VM Muse Spark (Hatch Runtime)** ke satu pusat gateway **9Router** menggunakan metode **SSH Reverse Tunnel** yang dilindungi oleh **Cloudflare Access**.

---

## ⚡ CARA TERCEPAT: 1-KLIK ZERO-TOUCH (TANPA PERLU BUKA VM 1)

Jika VM 1 sudah dipasangi Kunci Induk (*Master Mesh Key*), maka untuk setiap VM baru Anda **hanya perlu menjalankan 1 baris perintah saja**. Tidak perlu salin kunci, tidak perlu buka VM 1, dan tidak perlu chat ke Muse!

### 1️⃣ Untuk VM 2 (Worker Pertama)
Buka terminal VM 2 dan jalankan 1 perintah ini:
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/quick-connect.sh | bash -s 2 "PASTE_TOKEN_MASTER_KEY_DISINI"
```
> 🎉 **Selesai!** VM 2 langsung otomatis terhubung ke port `20130` di VM 1 seketika.

---

### 2️⃣ Untuk VM 3 (Worker Kedua)
Buka terminal VM 3 dan jalankan:
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/quick-connect.sh | bash -s 3 "PASTE_TOKEN_MASTER_KEY_DISINI"
```
> 🎉 **Selesai!** VM 3 langsung otomatis terhubung ke port `20131` di VM 1.

---

### 3️⃣ Untuk VM 4, VM 5, dst.
Tinggal ganti angka `3` di atas menjadi `4` (port 20132), `5` (port 20133), dst.

---

## 🛠️ CARA ALTERNATIF (Manual 2-Langkah)

Jika Anda ingin membuat kunci SSH terpisah per VM secara manual:

### Langkah A (Di Worker Baru)
```bash
git clone https://github.com/bluudzz/muse-multivm-mesh-tunnel.git /home/hatch/tunnel && /home/hatch/tunnel/install-worker.sh 2
```
Salin public key yang muncul di layar.

### Langkah B (Di VM 1 / Chat Muse)
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/register-vm1.sh | bash -s "PASTE_PUBLIC_KEY" 20130 "VM2"
```

---

## 🔀 Skalabilitas Multi-Worker (VM 3, VM 4, VM 5, dst.)

Sistem ini didesain **skalabel secara horizontal**. Anda bisa menghubungkan puluhan VM Muse Spark ke satu 9Router di VM 1 tanpa bentrok:

| Worker | Perintah Installer di Worker | Port di VM 1 | Model di 9Router |
|---|---|---|---|
| **VM 2** | `./install-worker.sh 2` | `20130` | `muse/muse-spark-vm2` |
| **VM 3** | `./install-worker.sh 3` | `20131` | `muse/muse-spark-vm3` |
| **VM 4** | `./install-worker.sh 4` | `20132` | `muse/muse-spark-vm4` |
| **VM 5** | `./install-worker.sh 5` | `20133` | `muse/muse-spark-vm5` |

### Cara Pasang di VM 3 (Contoh):
1. **Di terminal VM 3**, jalankan:
   ```bash
   git clone https://github.com/bluudzz/muse-multivm-mesh-tunnel.git /home/hatch/muse-multivm-mesh-tunnel && cd /home/hatch/muse-multivm-mesh-tunnel && chmod +x *.sh && ./install-worker.sh 3
   ```
2. **Di VM 1 (atau kirim ke AI Muse VM 1)**:
   ```bash
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/register-vm1.sh | bash -s "PASTE_PUBKEY_VM3" 20131 "VM3"
   ```
3. **Daftarkan provider baru ke 9Router**:
   - Provider Name: `Muse-VM3`
   - Base URL: `http://127.0.0.1:20131/v1`
   - Model: `muse/muse-spark-vm3`

---

## 📌 Arsitektur Sistem

```
┌─────────────────────────────────┐                 ┌─────────────────────────────────┐
│     VM 2 (Worker Muse Baru)     │                 │   VM 1 (9Router Central Hub)    │
│                                 │                 │                                 │
│  ┌───────────────────────────┐  │                 │  ┌───────────────────────────┐  │
│  │ Muse Spark (Port 20129)   │  │                 │  │ 9Router (Port 20128)      │  │
│  └─────────────┬─────────────┘  │                 │  │ (https://9router.ourme... │  │
│                │                │                 │  └─────────────▲─────────────┘  │
│                ▼                │                 │                │                │
│  ┌───────────────────────────┐  │  SSH Reverse    │  ┌─────────────┴─────────────┐  │
│  │ reverse-tunnel-vm1.service│──┼─────────────────┼─►│ Port Lokal 20130          │  │
│  └───────────────────────────┘  │  (via Cloudflare│  └───────────────────────────┘  │
│                                 │   ssh.ourme...) │                                 │
└─────────────────────────────────┘                 └─────────────────────────────────┘
```

Dengan sistem ini:
1. **VM 2** tidak memerlukan IP publik, port terbuka, ataupun konfigurasi domain Cloudflare Tunnel baru.
2. Port internal `20129` di VM 2 langsung dimunculkan sebagai port **`20130` di VM 1**.
3. **9Router di VM 1** cukup memanggil `http://127.0.0.1:20130/v1` secara lokal.
4. Tahan terhadap *VM Replacement* (otomatis pulih via `recover.sh`).

---

## 🚀 Panduan Cepat (Quick Start 3 Menit)

### Langkah 1: Jalankan Installer di VM 2 (Worker Baru)

Buka terminal di **VM 2**, lalu jalankan satu perintah ini:
```bash
git clone https://github.com/bluudzz/muse-multivm-mesh-tunnel.git /home/hatch/muse-multivm-mesh-tunnel
cd /home/hatch/muse-multivm-mesh-tunnel
chmod +x install-vm2.sh register-vm1.sh
./install-vm2.sh
```

Skrip ini akan:
- Membuat SSH Key khusus (`/home/hatch/.ssh/id_vm2`).
- Mengonfigurasi `~/.ssh/config` agar otomatis menembus Cloudflare SSH (`cloudflared access ssh`).
- Memasang systemd service `reverse-tunnel-vm1.service` (auto-reconnect).
- Menambahkan blok ke `/home/hatch/workspace/vm-recovery/recover.sh` (tahan VM replace).
- **Menampilkan Public Key VM 2 di layar**.

---

### Langkah 2: Daftarkan Public Key di VM 1 (Central Hub)

Salin baris kunci publik yang ditampilkan oleh skrip di Langkah 1.
Lalu buka terminal di **VM 1**, dan jalankan skrip pendaftaran:

```bash
# Jalankan skrip pendaftaran dengan menyertakan public key dari VM 2:
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/register-vm1.sh | bash -s "PASTE_PUBLIC_KEY_VM2_DISINI"
```

*Skrip ini akan memasukkan kunci VM 2 ke `authorized_keys` dan `authorized_keys_laptop` di VM 1.*

---

### Langkah 3: Daftarkan Worker ke 9Router di VM 1

1. Buka dashboard web 9Router VM 1:
   👉 **`https://9router.ourme.my.id/ui`** (atau `https://panelmuse.ourme.my.id`)
2. Masuk ke menu **Providers** ➔ Klik **Add Provider**.
3. Pilih tipe: **Custom OpenAI**.
4. Masukkan konfigurasi berikut:
   - **Provider Name**: `Muse-VM2`
   - **Base URL**: `http://127.0.0.1:20130/v1`
   - **API Key**: API key bridge VM 2 (bisa dicek di `/home/hatch/muse-bridge/config.json` di VM 2).
   - **Models**: `muse/muse-spark-vm2`
5. Klik **Save**.

---

## 🧪 Pengujian Koneksi

Setelah ketiga langkah di atas selesai, uji koneksi dari VM 1:
```bash
curl -s http://127.0.0.1:20130/v1/models
```
Jika respon JSON menampilkan model `muse-spark-1.3`, maka koneksi mesh antar-VM telah berhasil 100%!

Sekarang Anda bisa memanggil model tersebut langsung lewat endpoint publik 9Router:
```bash
curl -X POST https://9router.ourme.my.id/v1/chat/completions \
  -H "Authorization: Bearer <9ROUTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "muse/muse-spark-vm2",
    "messages": [{"role": "user", "content": "Halo dari VM 2!"}]
  }'
```

---

## 🛡️ Mengapa Tahan "VM Replace"?

Di lingkungan Hatch, semua file di luar direktori `/home/hatch/` akan terhapus jika penyedia melakukan *replace container*. 

Repositori ini menerapkan standar recovery:
1. Skrip reverse tunnel dan kunci SSH disimpan di `/home/hatch/.ssh/`.
2. Seluruh deklarasi service systemd otomatis di-append ke `/home/hatch/workspace/vm-recovery/recover.sh`.
3. Setiap kali VM dinyalakan ulang / diganti baru, koneksi reverse tunnel akan otomatis tersambung kembali.

---

## 📄 Lisensi
MIT License © 2026 bluudzz
