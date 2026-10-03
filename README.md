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

Buka terminal di **VM 1**, lalu jalankan satu baris perintah ini:

```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
```

**Apa yang terjadi?**
- Skrip otomatis menyiapkan folder SSH, membuat **Kunci Induk (Master Mesh Key)**, memasang gembok ke `authorized_keys`, dan mengamankannya ke `recover.sh` (anti-VM replace).
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

Buka terminal di VM Worker baru mana pun, lalu jalankan perintah di bawah ini (tempelkan token dari Langkah 1):

#### ▶ Untuk VM 2 (Worker Pertama):
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 2 "PASTE_TOKEN_DISINI"
```
> 🎉 **Selesai!** VM 2 langsung terhubung ke port **`20130`** di VM 1 secara otomatis.

#### ▶ Untuk VM 3 (Worker Kedua):
```bash
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s 3 "PASTE_TOKEN_DISINI"
```
> 🎉 **Selesai!** VM 3 langsung terhubung ke port **`20131`** di VM 1.

#### ▶ Untuk VM 4, VM 5, dst.:
Tinggal ganti angka `3` menjadi `4` (port `20132`), `5` (port `20133`), dst.

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

## 📌 Cara Daftarkan Provider di Dashboard 9Router

Setelah worker terhubung:
1. Buka dashboard web 9Router di VM 1:  
   👉 **`https://9router.ourme.my.id/ui`** (atau `http://127.0.0.1:20128/ui`)
2. Masuk ke menu **Providers** ➔ Klik **Add Provider**.
3. Pilih tipe: **Custom OpenAI**.
4. Isi konfigurasi:
   - **Provider Name**: `Muse-VM2` *(atau sesuai nama worker)*
   - **Base URL**: `http://127.0.0.1:20130/v1` *(sesuai nomor port worker)*
   - **API Key**: API key bridge worker (bebas/bisa dicek di `/home/hatch/muse-bridge/config.json`).
   - **Models**: `muse/muse-spark-vm2`
5. Klik **Save**.

---

## 🛡️ Fitur Anti "VM Replace" (Pemulihan Otomatis)

Semua skrip di repositori ini mematuhi standar Hatch Runtime:
- Semua konfigurasi disimpan di dalam `/home/hatch/`.
- Setiap service otomatis didaftarkan ke `/home/hatch/workspace/vm-recovery/recover.sh`.
- Jika VM di-replace atau di-restart oleh provider, seluruh koneksi tunnel dan otorisasi SSH akan **pulih otomatis secara mandiri tanpa campur tangan manusia**.

---

## 📄 Lisensi
MIT License © 2026 bluudzz
