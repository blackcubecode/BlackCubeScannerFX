# 🧊 Black Cube ScannerFX

> **Breakout Bridge EA + Python Signal Scanner untuk XAUUSD & Forex**
>
> Sinyal breakout dari Python. Eksekusi otomatis di MetaTrader 5. Tanpa perlu coding.

[![Version](https://img.shields.io/badge/version-1.11-blue.svg)](https://github.com/blackcubecode/BlackCubeScannerFX/releases)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205-orange.svg)](https://www.metatrader5.com/)
[![Python](https://img.shields.io/badge/python-3.10%2B-yellow.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 📖 Tentang Proyek

**Black Cube ScannerFX** adalah sistem trading hybrid yang menggabungkan **Python sebagai penyedia sinyal** dan **MetaTrader 5 (MT5) sebagai eksekutor order**.

Sistem ini dirancang untuk trader yang ingin mengotomatisasi strategi breakout dengan kontrol atas parameter sinyal, tanpa harus menulis kode Python atau MQL5.

Scanner berjalan sebagai aplikasi **standalone `.exe`** di background. Sistem menganalisis breakout berbasis ATR pada timeframe M1/M5, kemudian mengirimkan sinyal ke EA MT5 melalui koneksi TCP.

EA menerima sinyal, memvalidasi parameter trading seperti spread, Stop Loss (SL), Take Profit (TP), dan posisi aktif, kemudian memproses eksekusi order sesuai konfigurasi.

**Instrumen yang didukung:** XAUUSD, EURUSD, GBPUSD, dan pasangan Forex lain yang dikonfigurasi dengan benar.

**Keunggulan:** portable, ringan, dan tidak memerlukan instalasi Python pada komputer pengguna jika menggunakan versi EXE standalone.

---

## ✨ Fitur Utama

### 🧠 Signal Engine — Python

- **ATR-based breakout:** deteksi breakout berdasarkan volatilitas pasar.
- **Parameter fleksibel:** pengaturan lookback dan multiplier ATR melalui konfigurasi.
- **Multi-filter:** penyaringan berdasarkan spread, ATR minimum, serta arah SL/TP.
- **Auto SL/TP:** perhitungan jarak Stop Loss dan Take Profit berdasarkan volatilitas.
- **Multi-client:** satu scanner dapat melayani beberapa koneksi EA sesuai implementasi dan konfigurasi.
- **Logging:** pencatatan aktivitas scanner dan sinyal untuk membantu audit serta troubleshooting.

### 🛡️ Eksekusi Order — EA MT5

- **Validasi SL/TP:** pemeriksaan terhadap batas minimum jarak stop broker.
- **Spread filter:** menolak sinyal ketika spread melebihi batas konfigurasi.
- **One position only:** opsi membatasi jumlah posisi aktif.
- **ClampStop:** penyesuaian jarak stop untuk membantu menghindari error `10016 Invalid stops`.
- **Normalisasi lot:** penyesuaian volume berdasarkan minimum, maksimum, dan step broker.
- **Debug log:** pencatatan detail proses penerimaan sinyal dan eksekusi order.

### 🔌 Koneksi TCP

- **Auto-reconnect:** mencoba menghubungkan ulang dengan jeda sekitar 2 detik.
- **Chunked history:** pengiriman riwayat harga dalam potongan 100 bar untuk mengurangi risiko timeout.
- **Heartbeat PING:** pemeriksaan koneksi setiap 10 detik.
- **RX buffer cap:** pembatasan buffer penerimaan data.
- **Tick throttle:** pembatasan frekuensi pengiriman data untuk mengurangi beban sistem.

### 📦 Distribusi Portable

- **EXE standalone:** scanner dapat dijalankan tanpa instalasi Python terpisah.
- **Config.ini:** konfigurasi dapat diedit melalui Notepad.
- **Auto-create config:** konfigurasi dibuat ulang jika file tidak ditemukan, sesuai implementasi aplikasi.
- **Log rotation:** pengelolaan file log `scanner.log`.
- **Minim dependensi:** versi EXE tidak memerlukan instalasi Python, pip, atau hak administrator untuk penggunaan normal.

---

## 🎯 Untuk Siapa?

### ✅ Cocok untuk

- Trader breakout yang ingin mengotomatisasi trading XAUUSD dan Forex.
- Pengguna MT5 yang membutuhkan penyedia sinyal eksternal berbasis Python.
- Pemula yang ingin mencoba otomasi trading tanpa menulis kode sendiri.
- Trader multi-akun yang membutuhkan satu scanner untuk beberapa EA.
- Developer yang ingin mempelajari atau mengembangkan strategi melalui source code Python.

### ⚠️ Tidak cocok untuk

- Pengguna MetaTrader 4 (MT4), karena produk ini ditujukan untuk MT5.
- Trader yang mencari jaminan profit atau keuntungan tetap.
- Pengguna yang tidak memahami risiko trading dan manajemen modal.

---

## 📊 Spesifikasi Teknis

| Kategori | Spesifikasi |
|---|---|
| Produk | Black Cube ScannerFX |
| Versi | 1.11 |
| Platform trading | MetaTrader 5 |
| Minimum build MT5 | 3390 |
| Sistem operasi | Windows 10/11 64-bit |
| Instrumen | XAUUSD, EURUSD, GBPUSD, dan pair lain sesuai konfigurasi |
| Timeframe rekomendasi | M1–M5 |
| Broker | Broker MT5, dengan penyesuaian digit dan spesifikasi simbol |
| Komunikasi | TCP |
| Port default | 5555 |
| Lot awal konfigurasi | 0.01 |
| Format scanner | EXE standalone |
| Perkiraan ukuran EXE | ±30 MB |
| Perkiraan RAM | Kurang dari 50 MB |
| Bahasa | Python 3.12 bundled dan MQL5 |

> **Catatan:** kebutuhan sumber daya, kompatibilitas build, dan perilaku eksekusi dapat berbeda tergantung versi aplikasi, broker, jumlah koneksi, dan konfigurasi. Angka di atas merupakan spesifikasi yang ditargetkan, bukan jaminan hasil pada semua komputer.

---

## 🚀 Panduan Instalasi dan Penggunaan

### 1. Extract ZIP dan Jalankan Scanner

1. Unduh paket rilis terbaru dari [GitHub Releases](https://github.com/blackcubecode/BlackCubeScannerFX/releases).
2. Extract ZIP ke folder yang mudah ditemukan, misalnya `D:\ScannerFX`.
3. Buka folder hasil extract.
4. Jalankan `BlackCubeScannerFX.exe`.
5. Pastikan scanner berjalan dan periksa log untuk memastikan tidak ada error.

Jika file `config.ini` tersedia, periksa konfigurasinya sebelum menghubungkan EA.

### 2. Pasang EA pada MetaTrader 5

1. Buka MetaTrader 5 dan login ke akun trading yang ingin digunakan.
2. Buka chart simbol yang sesuai, misalnya `XAUUSD` pada timeframe M5.
3. Pasang EA `BlackCubeScannerFX_Breakout` pada chart.
4. Aktifkan **Algo Trading**.
5. Pada pengaturan EA, buka tab **Common** dan aktifkan izin trading algoritmik.
6. Pastikan simbol, port, serta parameter koneksi EA sesuai dengan konfigurasi scanner.

Jika EA menggunakan fungsi WebRequest, tambahkan URL yang benar ke daftar izin WebRequest MT5. Jika EA menggunakan TCP socket secara langsung, periksa pengaturan dan izin koneksi yang memang berlaku untuk implementasi tersebut.

### 3. Verifikasi Koneksi dan Tunggu Sinyal

Periksa indikator koneksi dan log pada kedua aplikasi.

**Pada chart MT5:**

- Status koneksi diharapkan menunjukkan `CONNECTED`, sesuai implementasi EA.

**Pada log MT5 Experts:**

```text
[Bridge] CONNECTED + HELLO + history sent OK
```

**Pada log scanner:**

```text
HELLO ... sym=XAUUSD digits=2
```

Pesan di atas merupakan contoh log yang diharapkan, bukan pesan yang harus selalu identik pada setiap versi.

Setelah koneksi berhasil, scanner dapat memproses data pasar dan mengirimkan sinyal breakout. Order hanya diproses jika sinyal memenuhi filter serta aturan eksekusi EA.

> **Penting:** uji koneksi dan strategi pada akun demo terlebih dahulu. Status `CONNECTED` tidak menjamin bahwa order akan berhasil dieksekusi atau menghasilkan keuntungan.

---

## 📁 Struktur Repository

```text
BlackCubeScannerFX/
├── scanner.py
├── protocol.py
├── strategy.py
├── requirements.txt
├── config.ini
├── BlackCubeScannerFX_Breakout.mq5
├── README.md
├── LICENSE
├── .gitignore
├── qris-donasi.jpg
└── dist/
    ├── BlackCubeScannerFX.exe
    └── config.ini
```

| File/Folder | Fungsi |
|---|---|
| `scanner.py` | Program utama scanner dan server TCP |
| `protocol.py` | Parser protokol komunikasi |
| `strategy.py` | Logika deteksi breakout dan sinyal |
| `requirements.txt` | Daftar dependensi Python |
| `config.ini` | Konfigurasi scanner |
| `BlackCubeScannerFX_Breakout.mq5` | Source code EA untuk MT5 |
| `dist/` | Distribusi aplikasi standalone |
| `qris-donasi.jpg` | Gambar QRIS donasi |

> Struktur di atas mengikuti susunan repository yang didokumentasikan. Pastikan nama dan lokasi file sesuai dengan paket rilis yang digunakan.

---

## ⚙️ Konfigurasi Scanner

Buka file `config.ini` menggunakan Notepad. Sesuaikan parameter berikut dengan simbol, spesifikasi harga, dan kondisi broker.

```ini
[scanner]
host = 0.0.0.0
port = 5555
magic = 555501
symbol = XAUUSD
digits = 2
point = 0.01
account_login = 0
history_bars = 1000
breakout_lookback = 30
atr_period = 14
atr_mult_sl = 1.8
atr_mult_tp = 3.6
risk_lot = 0.01
min_spread_points = 0
max_spread_points = 60
cooldown_bars = 3
allow_buy = true
allow_sell = true
log_level = INFO
```

**Perhatian:** pastikan nama simbol cocok dengan nama yang digunakan broker, misalnya `XAUUSD`, `XAUUSD.a`, atau `XAUUSDm`.

Nilai `digits` dan `point` juga harus sesuai dengan spesifikasi simbol di MT5. Jangan mengubah parameter tersebut berdasarkan perkiraan saja.

Jika scanner hanya digunakan di komputer yang sama dengan EA, pertimbangkan untuk mengikat server ke alamat loopback apabila didukung oleh implementasi aplikasi. Penggunaan `0.0.0.0` memungkinkan server mendengarkan pada semua antarmuka jaringan, sehingga aksesnya perlu dibatasi sesuai kebutuhan.

### 📌 Parameter Penting

| Parameter | Fungsi | Nilai Awal/Rekomendasi |
|---|---|---|
| `breakout_lookback` | Jumlah bar untuk menentukan level breakout | 20–40; contoh XAUUSD: 30 |
| `atr_period` | Periode perhitungan ATR | 14 |
| `atr_mult_sl` | Multiplier ATR untuk jarak SL | 1.5–2.5 |
| `atr_mult_tp` | Multiplier ATR untuk jarak TP | 3.0–4.0 |
| `max_spread_points` | Batas spread maksimum yang diterima | 60–100, sesuaikan broker |
| `risk_lot` | Ukuran lot sesuai implementasi scanner/EA | Mulai dari 0.01 pada akun demo |
| `cooldown_bars` | Jeda dalam bar sebelum sinyal berikutnya | 3 |
| `history_bars` | Jumlah bar riwayat yang diminta | 1000 |
| `port` | Port komunikasi TCP | 5555 |

Nilai di atas adalah titik awal untuk pengujian, bukan rekomendasi investasi atau jaminan bahwa strategi akan menguntungkan.

---

## 🔧 Troubleshooting

| Gejala | Kemungkinan Penyebab | Langkah Pemeriksaan |
|---|---|---|
| EA menunjukkan `DISCONNECTED` | Scanner mati, port salah, atau koneksi gagal | Pastikan EXE berjalan dan port pada scanner sama dengan port EA |
| Error `4014` | Operasi atau fungsi yang dipanggil tidak diizinkan atau tidak tersedia pada konteks tersebut | Periksa pesan lengkap di log, fungsi EA yang digunakan, serta konfigurasi MT5 |
| Order `REJECT SPREAD` | Spread melebihi batas konfigurasi | Periksa spread aktual dan `max_spread_points` |
| Error `10016 Invalid stops` | SL/TP tidak memenuhi batas broker atau harga berubah | Periksa StopLevel, FreezeLevel, normalisasi harga, dan multiplier ATR |
| `SendLine FAILED` | Pengiriman data gagal atau koneksi terputus | Periksa `scanner.log`, log MT5, dan status koneksi |
| Port 5555 sudah digunakan | Ada proses lain yang memakai port tersebut | Identifikasi proses pemilik port, atau ubah port di scanner dan EA |
| Scanner langsung tertutup | Kesalahan konfigurasi atau masalah runtime | Jalankan dari terminal agar pesan error dapat terlihat |
| Sinyal tidak menghasilkan order | Filter tidak terpenuhi, trading dinonaktifkan, atau order ditolak broker | Periksa log scanner, tab Experts, spread, volume, dan izin trading |

### Pemeriksaan Port di Windows

Buka Command Prompt, lalu jalankan:

```bat
netstat -ano | findstr :5555
```

Perintah ini membantu memeriksa apakah ada proses yang menggunakan port 5555.

Jika perlu mengidentifikasi PID yang ditemukan, gunakan:

```bat
tasklist /FI "PID eq 1234"
```

Ganti `1234` dengan PID aktual dari hasil pemeriksaan.

> Jangan menghentikan proses secara sembarangan. Pastikan proses tersebut memang aman untuk dihentikan sebelum melakukan perubahan.

---

## 🎁 Roadmap

- [x] **v1.0** — MVP scanner dan EA bridge.
- [x] **v1.1** — Bugfix, hardening, dan chunked history.
- [x] **v1.11** — `config.ini`, portable EXE, dan heartbeat.
- [ ] **v1.2** — Trailing Stop dan Breakeven.
- [ ] **v1.3** — Session Filter London/New York.
- [ ] **v1.4** — Multi-pair dan dashboard web.
- [ ] **v2.0** — Risk-based lot sizing dan equity guard.

---

## ⚠️ Disclaimer dan Manajemen Risiko

Black Cube ScannerFX merupakan **perangkat lunak bantu trading**, bukan jaminan profit. Trading Forex dan emas memiliki risiko kehilangan sebagian atau seluruh modal.

Sebelum menggunakan sistem:

- Uji strategi setidaknya selama dua minggu pada akun demo sebagai tahap awal evaluasi.
- Mulai dengan volume kecil dan pahami nilai pergerakan harga pada simbol yang digunakan.
- Periksa pengaturan SL, TP, spread, serta spesifikasi broker.
- Pantau sistem, koneksi, dan log secara berkala.
- Jangan menggunakan dana yang tidak sanggup Anda tanggung jika hilang.
- Ingat bahwa performa masa lalu tidak menjamin hasil di masa depan.

Dengan menggunakan produk ini, pengguna memahami bahwa:

1. Developer tidak menjamin profit atau hasil trading tertentu.
2. Penggunaan perangkat lunak dilakukan dengan mempertimbangkan risiko trading dan ketentuan yang berlaku.
3. Ketentuan refund mengikuti kebijakan penjualan yang berlaku dan hukum yang relevan.
4. Dukungan teknis diberikan sesuai paket pembelian dan ketentuan layanan.

Disclaimer ini tidak menghapus hak konsumen yang diwajibkan oleh hukum yang berlaku.

---

## 💖 Support dan Donasi

Jika proyek ini bermanfaat, dukung pengembangan Black Cube ScannerFX melalui donasi sukarela.

<p align="center">
  <img
    src="qris-donasi.jpg"
    width="300"
    alt="QRIS Donasi Black Cube Code"
  >
</p>

<p align="center">
  <em>Terima kasih atas dukungan Anda untuk pengembangan software independen.</em>
</p>

---

## 📞 Kontak Developer

**BLACK CUBE CODE**

*Independent Developer — Expert Advisor and Algorithmic Trading*

- **Telegram:** [@blackcubecodeadmin](https://t.me/blackcubecodeadmin)
- **GitHub Repository:** [BlackCubeScannerFX](https://github.com/blackcubecode/BlackCubeScannerFX)
- **GitHub Issues:** [Laporkan Bug atau Ajukan Fitur](https://github.com/blackcubecode/BlackCubeScannerFX/issues)

---

<p align="center">
  <strong>🧊 Black Cube ScannerFX v1.11</strong><br>
  <em>Automate the breakout. Control the risk.</em>
</p>
