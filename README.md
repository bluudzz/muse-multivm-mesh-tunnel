# 🌐 Muse Multi-VM Mesh Tunnel & Orchestrator

Hubungkan dan **kendalikan penuh** banyak VM Worker AI (VM 2, VM 3, dst.) langsung dari satu Server Utama (**VM 1 Central Hub**) secara otomatis.

> 💡 **Mudah untuk Orang Awam:**  
> Jika Anda mengoperasikan server melalui AI Agen (seperti bot Muse / Hermes di Hatch) dan tidak memiliki akses CMD langsung, Anda **cukup menyalin teks prompt di bawah ini** dan mengirimkannya ke chat AI di masing-masing VM!

---

## ⚡ Panduan Cepat (Cukup Lewat Chat AI di Masing-Masing VM)

```
[ VM 1 - Hub Utama ]  ──(Token Induk)──>  [ VM 2 / VM 3 Worker ]
         │                                       │
         ▼                                       ▼
  Jalankan Prompt 1                       Jalankan Prompt 2
         │                                       │
         └─────────────◄ Tunnel 2 Arah ──────────┘
                  (AI 9Router + Remote SSH)
```

---

### 1️⃣ Langkah 1: Siapkan Server Utama (VM 1 - Hub Pusat)

Buka chat AI di **VM 1**, lalu salin dan kirim prompt berikut:

```text
Tolong siapkan server ini sebagai Hub Pusat (VM 1) untuk Muse Multi-VM Mesh Tunnel:
1. Pastikan port 20128 (9Router) dan OpenSSH server aktif.
2. Jalankan perintah instalasi resmi:
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
3. Setelah selesai, tampilkan teks MASTER TOKEN yang dihasilkan dengan jelas agar bisa saya salin untuk VM worker berikutnya.
```

👉 **Hasil dari Langkah 1:**  
AI di VM 1 akan membalas dengan teks kode acak panjang bernama **MASTER TOKEN**. Simpan token ini untuk Langkah 2!

---

### 2️⃣ Langkah 2: Hubungkan Worker Baru (VM 2, VM 3, dst.)

Buka chat AI di **VM Worker** yang ingin Anda hubungkan (misalnya di VM 2, VM 3, dst.).

> 💡 **Trik Praktis (Tanpa Perlu Edit Teks di Chat):**  
> Anda tidak perlu repot mengedit teks perintah di chat. Cukup **salin teks prompt di bawah ini mentah-mentah**, lalu kirim ke AI Worker. Si AI akan secara otomatis menanyakan 3 data yang diperlukan langsung kepada Anda di chat!

#### 💬 Salin & Kirim Prompt Ini ke AI di VM Worker:

```text
Saya ingin menghubungkan server ini sebagai Worker Node ke Server Utama (VM 1) menggunakan Muse Mesh Tunnel.

⚠️ ATURAN SEBELUM EKSEKUSI:
Jangan jalankan perintah instalasi dulu. Tolong tanyakan kepada saya 3 data berikut:
1. Berapa Nomor Worker untuk VM ini? (contoh: 2 untuk VM ke-2, 3 untuk VM ke-3, dst.)
2. Apa Hostname / Domain SSH VM 1? (contoh: ssh.ourme.my.id atau IP publik VM 1)
3. Apa Master Token Kunci Induk dari VM 1?

Setelah saya memberikan ketiga data tersebut, jalankan perintah instalasi berikut di terminal:
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s -- --worker <NOMOR_DARI_USER> --host <HOST_DARI_USER> --token "<TOKEN_DARI_USER>"

Setelah selesai, periksa dan laporkan apakah service reverse-tunnel-worker<NOMOR> dan muse-bridge sudah aktif (running).
```

---

#### 🔄 Contoh Alur Balasan dari AI di Worker:
1. Anda mengirim prompt di atas.
2. AI Worker akan membalas:  
   *"Baik! Sebelum saya mulai, tolong berikan 3 data: (1) Nomor Worker, (2) Domain SSH VM 1, dan (3) Master Token?"*
3. Anda cukup menjawab di chat, misalnya:  
   ```text
   1. 2
   2. ssh.ourme.my.id
   3. LS0tLS1CRUdJTiBPUEVOU1NIIFBSSV...
   ```
4. AI Worker akan otomatis merangkai dan menjalankan instalasi sampai selesai!

🎉 **Selesai!**  
Begitu AI worker melapor sukses, model AI worker langsung terdaftar di 9Router VM 1, dan VM 1 kini memiliki akses penuh untuk mengendalikan worker tersebut!

---

### 3️⃣ Langkah 3: Mengendalikan Worker dari VM 1

Setelah worker terhubung, Anda dapat memantau dan mengendalikan seluruh worker langsung dari **VM 1**.

#### A. Mengendalikan Lewat Chat AI di VM 1:
Cukup kirim instruksi ke chat AI di VM 1 seperti biasa:
- **Melihat status koneksi worker:**  
  *"Tolong jalankan `mesh list` dan periksa apakah VM 2 sudah online."*
- **Menjalankan perintah di worker:**  
  *"Tolong jalankan `mesh exec 2 "uptime"` untuk melihat beban kerja VM 2."*
- **Mengecek seluruh worker serentak:**  
  *"Tolong jalankan `mesh exec all "df -h"` untuk cek sisa disk di semua worker."*

#### B. Mengendalikan Lewat Terminal VM 1 (Jika Anda membuka terminal):
Tool **`mesh`** sudah otomatis terpasang di VM 1:

| Perintah | Penjelasan Fungsi |
| :--- | :--- |
| `mesh list` | Menampilkan tabel status semua worker (SSH & Model AI) |
| `mesh ssh 2` | Langsung masuk ke shell terminal VM 2 (tanpa password) |
| `mesh exec 2 "perintah"` | Menjalankan perintah di VM 2 dari jauh |
| `mesh exec all "uptime"` | Menjalankan perintah serentak di SEMUA worker |
| `mesh push 2 <lokal> <remote>` | Mengirim file dari VM 1 ke VM 2 |
| `mesh pull 2 <remote> <lokal>` | Mengambil file dari VM 2 ke VM 1 |
| `mesh restart 2 muse-bridge` | Restart service di worker dari jauh |

---

## 🖥️ Pilihan Alternatif: Jalankan Manual di Terminal Keyboard

Bagi Anda yang memiliki akses langsung ke keyboard terminal Bash:

1. **Di VM 1 (Server Utama):**
   ```bash
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
   ```
   *(Salin teks TOKEN yang ditampilkan di layar).*

2. **Di VM Worker (VM 2, VM 3, dst.):**
   ```bash
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash
   ```
   *(Skrip akan otomatis bertanya nomor worker, host SSH, dan token).*

---

## 🗺️ Skema Pemetaan Port Jaringan

| Node Worker | Endpoint Model AI di VM 1 | Port SSH Kendali di VM 1 | Akses Langsung dari VM 1 |
| :--- | :--- | :--- | :--- |
| **VM 2** | `http://127.0.0.1:20130/v1` | `22002` | `mesh ssh 2` |
| **VM 3** | `http://127.0.0.1:20131/v1` | `22003` | `mesh ssh 3` |
| **VM 4** | `http://127.0.0.1:20132/v1` | `22004` | `mesh ssh 4` |
| **VM $N$** | `http://127.0.0.1:$((20128+N))/v1` | `$((22000+N))` | `mesh ssh $N$` |

---

## 🛡️ Anti-VM Replace (Pemulihan Otomatis)

Semua konfigurasi dan terowongan otomatis didaftarkan ke `/home/hatch/workspace/vm-recovery/recover.sh` dan dipantau cron tiap 1 menit.  
Jika VM Anda di-reboot atau diganti baru (*replaced*) oleh provider sewaktu-waktu, sistem akan otomatis pulih kembali tanpa Anda perlu memasang ulang!

---

## 📄 Lisensi
MIT License © 2026 bluudzz

