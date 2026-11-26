# Skrip Pengujian Mandiri Rapih Euy Rust Engine

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Pengujian Mandiri Backend Rapih Euy     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Pastikan build engine selesai via build-engine.mjs (otomatis deteksi MSVC/GNU)
Write-Host "`n[1/4] Mengompilasi rapih_engine..." -ForegroundColor Yellow
node scripts/build-engine.mjs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Kompilasi rapih_engine gagal!"
    exit 1
}

$engineExe = "rapih_engine\target\release\rapih_engine.exe"
if (-not (Test-Path $engineExe)) {
    Write-Error "Binary rapih_engine.exe tidak ditemukan!"
    exit 1
}
Write-Host "Engine siap di: $engineExe" -ForegroundColor Green

# 2. Siapkan Sandbox Pengujian
Write-Host "`n[2/4] Menyiapkan Sandbox folder uji coba (test_sandbox)..." -ForegroundColor Yellow
$sandbox = "test_sandbox"
if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }
New-Item -ItemType Directory -Path "$sandbox\empty_folder" -Force | Out-Null
New-Item -ItemType Directory -Path "$sandbox\nested" -Force | Out-Null

# Buat file sementara
"Data sementara log 2026" | Set-Content "$sandbox\debug.tmp"
"Data installer pura-pura" | Set-Content "$sandbox\setup_lama.exe"
"Laporan penting proyek.pdf" | Set-Content "$sandbox\laporan.pdf"
"Gambar pemandangan indah" | Set-Content "$sandbox\wallpaper.png"

# Buat file duplikat identik
$sampleData = "KONTEN_IDENTIK_UNTUK_DIUJI_BLAKE3_HASH_12345"
$sampleData | Set-Content "$sandbox\file_asli.txt"
$sampleData | Set-Content "$sandbox\file_asli_copy.txt"

Write-Host "File pengujian berhasil dibuat di $sandbox" -ForegroundColor Green

# 3. Uji Coba Disk Info
Write-Host "`n[3/4] Menguji Pembacaan Ruang Disk (disk_info)..." -ForegroundColor Yellow
$diskOutput = & $engineExe --cmd disk_info
Write-Host "Hasil disk_info:" -ForegroundColor Gray
Write-Host $diskOutput

# 4. Uji Coba Auto-Organizer & Rekomendasi di sandbox
Write-Host "`n[4/4] Menguji Smart Auto-Organizer & Scanner di folder sandbox..." -ForegroundColor Yellow
$sandboxFull = (Resolve-Path $sandbox).Path
$organizePlan = & $engineExe --cmd scan_organizer $sandboxFull
Write-Host "Hasil Rencana Auto-Organizer:" -ForegroundColor Gray
Write-Host $organizePlan

$recResult = & $engineExe --cmd scan_recommendations $sandboxFull
Write-Host "`nHasil Scan Rekomendasi (termasuk deteksi duplikat & folder kosong):" -ForegroundColor Gray
Write-Host $recResult

$delFile = (Resolve-Path "$sandbox\debug.tmp").Path
$delResult = & $engineExe --cmd delete_files $delFile
Write-Host "`nHasil Uji Hapus Langsung (delete_files):" -ForegroundColor Gray
Write-Host $delResult

# Bersihkan sandbox sementara
Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "  Semua Pengujian Berhasil Berjalan!      " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
