# 🌐 Muse Multi-VM Mesh Tunnel & Master Orchestrator

Hubungkan, kendalikan, dan satukan seluruh VM Worker AI (VM 2, VM 3, dst.) ke dalam satu Server Utama (**VM 1**) secara otomatis. Dilengkapi fitur **Zero-Touch Self-Healing** (kebal VM replace & anti-401 key mismatch).

---

### 1️⃣ Langkah 1: Siapkan Server Utama (VM 1 — Master Hub)

Kirim prompt ini ke chat AI di **VM 1**:

```text
Tolong siapkan server ini sebagai Hub Pusat Kendali (VM 1):
1. Pastikan port 20128 (9Router) dan OpenSSH server aktif.
2. Jalankan perintah instalasi resmi:
   curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-hub.sh | bash
3. Setelah selesai, tampilkan MASTER TOKEN yang dihasilkan untuk saya salin ke worker.
```

---

### 2️⃣ Langkah 2: Hubungkan Worker (VM 2, VM 3, dst.)

Kirim prompt ini ke chat AI di **VM Worker**:

```text
Saya ingin menghubungkan server ini sebagai Worker Node ke Server Utama (VM 1).

⚠️ ATURAN SEBELUM EKSEKUSI:
Tanyakan kepada saya 3 data berikut terlebih dahulu:
1. Nomor Worker untuk VM ini? (contoh: 2, 3, dst.)
2. Hostname / Domain SSH VM 1? (contoh: ssh.ourme.my.id)
3. Master Token dari VM 1?

Setelah saya jawab, jalankan perintah instalasi resmi berikut di terminal:
curl -sSL https://raw.githubusercontent.com/bluudzz/muse-multivm-mesh-tunnel/main/setup-worker.sh | bash -s -- --worker <NOMOR_WORKER> --host <HOST_VM1> --token "<TOKEN_VM1>"
```

---

### 3️⃣ Langkah 3: Kendalikan Seluruh Worker dari VM 1

Gunakan utilitas **`mesh`** langsung di terminal atau via chat AI di VM 1:

| Perintah | Fungsi |
| :--- | :--- |
| `mesh list` | Cek status kesehatan seluruh worker (Agent & Model AI) |
| `mesh sync-keys` | Sinkronisasi ulang bridge key worker ke 9Router (*otomatis 24/7*) |
| `mesh ssh 2` | Masuk ke terminal shell interaktif Worker VM 2 |
| `mesh exec 2 "<cmd>"` | Jalankan perintah bash di VM 2 dari jarak jauh |
| `mesh exec all "<cmd>"` | Jalankan perintah serentak ke SELURUH worker |
| `mesh restart 2 [svc]` | Restart service di worker dari jauh (default: muse-bridge) |
| `mesh push 2 <src> <dst>` | Kirim file dari VM 1 ke worker |
| `mesh pull 2 <src> <dst>` | Ambil file dari worker ke VM 1 |

---

### 🗺️ Pemetaan Port di VM 1

| Node Worker | Endpoint Model AI di VM 1 | Port Kendali Remote di VM 1 | Akses Shell |
| :--- | :--- | :--- | :--- |
| **VM 2** | `http://127.0.0.1:20130/v1` | `22002` (Mesh Agent) | `mesh ssh 2` |
| **VM 3** | `http://127.0.0.1:20131/v1` | `22003` (Mesh Agent) | `mesh ssh 3` |
| **VM $N$** | `http://127.0.0.1:$((20128+N))/v1` | `$((22000+N))` | `mesh ssh $N$` |

---

### 🛡️ Fitur Zero-Touch & Anti-VM Replace
1. **Otomatis 24/7 Anti-401:** Watchdog timer di VM 1 memantau dan menyinkronkan kunci bridge setiap menit secara otonom.
2. **Kebal VM Replace:** Seluruh konfigurasi dan service tersimpan permanen di `/home/hatch/workspace/vm-recovery/recover.sh`. Jika VM di-replace provider, koneksi mesh dan pendaftaran model langsung pulih sendiri!

---

## 📄 Lisensi
MIT License © 2026 bluudzz
