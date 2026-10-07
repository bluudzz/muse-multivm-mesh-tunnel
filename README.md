# 🌐 Muse Multi-VM Mesh Tunnel & Orchestrator

Hubungkan dan kendalikan banyak VM Worker AI (VM 2, VM 3, dst.) langsung dari satu Server Utama (**VM 1**) secara otomatis.

---

### 1️⃣ Langkah 1: Siapkan Server Utama (VM 1)

Kirim prompt ini ke chat AI di **VM 1**:

```text
Tolong siapkan server ini sebagai Hub Pusat (VM 1) untuk Muse Multi-VM Mesh Tunnel:
1. Pastikan port 20128 (9Router) dan OpenSSH server aktif.
2. Jalankan perintah instalasi resmi:
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
3. Setelah selesai, tampilkan teks MASTER TOKEN yang dihasilkan dengan jelas agar bisa saya salin untuk VM worker berikutnya.
```

---

### 2️⃣ Langkah 2: Hubungkan Worker (VM 2, VM 3, dst.)

Kirim prompt ini ke chat AI di **VM Worker**:

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

### 3️⃣ Langkah 3: Mengendalikan Worker dari VM 1

Gunakan tool **`mesh`** di VM 1 (bisa lewat Chat AI atau Terminal):

| Perintah | Fungsi |
| :--- | :--- |
| `mesh list` | Cek status online semua worker (Control & Model AI) |
| `mesh sync-keys` | Sinkronisasi otomatis bridge key worker ke 9Router (Anti-401) |
| `mesh ssh 2` | Buka terminal shell interaktif ke VM 2 langsung |
| `mesh exec 2 "uptime"` | Jalankan perintah bash di VM 2 dari VM 1 |
| `mesh exec all "df -h"` | Jalankan perintah serentak ke SEMUA worker |
| `mesh push 2 <lokal> <remote>` | Kirim file dari VM 1 ke VM 2 |
| `mesh pull 2 <remote> <lokal>` | Ambil file dari VM 2 ke VM 1 |
| `mesh restart 2 muse-bridge` | Restart service di VM 2 dari jarak jauh |

---

## 🗺️ Pemetaan Port di VM 1

| Node Worker | Endpoint Model AI di VM 1 | Port SSH Kendali di VM 1 | Akses Shell dari VM 1 |
| :--- | :--- | :--- | :--- |
| **VM 2** | `http://127.0.0.1:20130/v1` | `22002` | `mesh ssh 2` |
| **VM 3** | `http://127.0.0.1:20131/v1` | `22003` | `mesh ssh 3` |
| **VM 4** | `http://127.0.0.1:20132/v1` | `22004` | `mesh ssh 4` |
| **VM $N$** | `http://127.0.0.1:$((20128+N))/v1` | `$((22000+N))` | `mesh ssh $N$` |

---

## 🖥️ Alternatif: Jalankan Manual di Terminal Keyboard
- **Di VM 1:** `curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash`
- **Di Worker:** `curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash`

---

## 🛡️ Anti-VM Replace (Pemulihan Otomatis)
Semua konfigurasi terowongan otomatis didaftarkan ke `/home/hatch/workspace/vm-recovery/recover.sh` dan dipantau cron tiap 1 menit. Jika VM di-reboot atau diganti baru (*replaced*), koneksi mesh akan otomatis pulih sendiri!

---

## 📄 Lisensi
MIT License © 2026 bluudzz
