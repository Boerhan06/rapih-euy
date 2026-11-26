# Arsitektur Aplikasi Rapih Euy

Aplikasi manajemen, pengurutan, dan pembersih disk cerdas dengan proteksi privasi dan keamanan tinggi.

## 1. Komponen Utama

```
+-------------------------------------------------------------+
|                 Flutter Desktop UI (rapih_ui)               |
|  - Desain Pastel: Matcha Green, Warm Oatmeal & Charcoal      |
|  - Dual-Pane Layout: Sidebar Navigasi & File Action Cards   |
|  - Prinsip "Selalu Tanya Aku": Checkbox individual          |
+-------------------------------------------------------------+
                              |
                     JSON-RPC / Subprocess
                              |
+-------------------------------------------------------------+
|                 Rust Backend Engine (rapih_engine)          |
|  - Sysinfo: Analisis ruang disk Windows                     |
|  - WalkDir: Pemindaian cepat Temp & Installer               |
|  - Blake3: Hashing instan pendeteksi duplikat identik       |
|  - Organizer: Smart grouping file ke subfolder kategori     |
|  - Quarantine Vault: Isolasi aman (.rapih_quarantine)       |
+-------------------------------------------------------------+
```

## 2. Mekanisme Keamanan ("Selalu Tanya Aku")

1. **Tidak Ada Penghapusan Otomatis**:
   - Engine hanya memberikan **rekomendasi**.
   - Setiap file memiliki checkbox yang bisa dipilih atau dibatalkan oleh pengguna.
2. **Karantina Khusus (Bukan Hapus Permanen)**:
   - Ketika pengguna menyetujui pembersihan, file dipindahkan ke brankas Karantina (`.rapih_quarantine` / AppData Vault).
   - Metadata tersimpan rapi di `quarantine_index.json` (lokasi asal, ukuran, tanggal, hash).
   - Pengguna bisa me-restore file kapan saja dengan 1 klik kembali ke lokasi asalnya.
3. **Smart Auto-Organizer**:
   - Membaca folder acak (misal: Downloads).
   - Mengelompokkan berdasarkan ekstensi (Dokumen, Gambar, Video, Audio, Setup, Arsip, Dev).
   - Menyediakan resolusi tabrakan nama file (`file_1.ext`) agar tidak ada data yang tertimpa.

## 3. Palet Warna (Matcha & Warm Oatmeal)

- **Warm Oatmeal Cream (`#F8F6EE`)**: Warna latar belakang yang lembut dan ramah di mata.
- **Matcha Green Pastel (`#D5E5D5` / `#2E5339`)**: Aksen badge kategori, status aman, dan tombol sorotan.
- **Charcoal Slate (`#22252A`)**: Kontras tinggi untuk teks judul, kartu utama, dan tombol aksi tegas.
- **Card Radius (22-28px)**: Tampilan modern bergaya mobile card seperti referensi visual.
