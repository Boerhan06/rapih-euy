# Skrip Pengujian Mandiri Rapih Euy Rust Engine

$ErrorActionPreference = "Stop"
$cargoPath = "$env:USERPROFILE\.cargo\bin\cargo.exe"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Pengujian Mandiri Backend Rapih Euy     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Pastikan build engine selesai
Write-Host "`n[1/4] Mengompilasi rapih_engine..." -ForegroundColor Yellow
Push-Location "rapih_engine"
try {
    & $cargoPath build
} finally {
    Pop-Location
}

$engineExe = "rapih_engine\target\debug\rapih_engine.exe"
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

# 4. Uji Coba Auto-Organizer
Write-Host "`n[4/4] Menguji Smart Auto-Organizer di folder sandbox..." -ForegroundColor Yellow
$organizePlan = & $engineExe --cmd scan_organizer (Resolve-Path $sandbox).Path
Write-Host "Hasil Rencana Auto-Organizer:" -ForegroundColor Gray
Write-Host $organizePlan

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "  Semua Pengujian Berhasil Berjalan!      " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
