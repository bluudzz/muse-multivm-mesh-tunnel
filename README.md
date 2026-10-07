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

Buka chat AI di **VM Worker** yang ingin dihubungkan (contohnya VM 2).  
Salin prompt di bawah ini, **ganti teks di dalam tanda `<...>`** dengan data Anda, lalu kirim ke AI di VM Worker:

```text
Tolong hubungkan server ini sebagai Worker Node (VM 2) ke Server Utama (VM 1) menggunakan Muse Mesh Tunnel.

Jalankan perintah instalasi berikut di terminal sistem:
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s -- --worker 2 --host <DOMAIN_SSH_VM1> --token "<TOKEN_DARI_LANGKAH_1>"

Setelah selesai, periksa dan laporkan apakah service reverse-tunnel-worker2 dan muse-bridge sudah aktif (running).
```

> 💡 **Contoh pengisian nyata:**
> ```text
> Tolong hubungkan server ini sebagai Worker Node (VM 2) ke Server Utama (VM 1) menggunakan Muse Mesh Tunnel.
> 
> Jalankan perintah instalasi berikut di terminal sistem:
> curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s -- --worker 2 --host ssh.ourme.my.id --token "LS0tLS1CRUdJTiBPUEVOU1NIIFBSSV..."
> 
> Setelah selesai, periksa dan laporkan apakah service reverse-tunnel-worker2 dan muse-bridge sudah aktif (running).
> ```

*(Untuk VM 3, VM 4, dst.: Cukup ubah angka `2` menjadi `3`, `4`, dst.)*

🎉 **Selesai!**  
Begitu AI worker membalas sukses, model AI worker langsung terdaftar di 9Router VM 1, dan VM 1 kini memiliki akses penuh untuk mengendalikan worker tersebut!

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

