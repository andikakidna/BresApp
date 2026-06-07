$ErrorActionPreference = 'SilentlyContinue'

function Get-UID {
    param ([string]$pkg)
    $uid = [string](adb shell "stat -c %u /data/data/$pkg 2>/dev/null").Trim()
    if ([string]::IsNullOrEmpty($uid) -or $uid -match "No such file") { return $null }
    return $uid
}

# --- LOOP UTAMA (LEVEL APLIKASI/GAME) ---
while ($true) {
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "     MADNDK MANUAL PUSHER (DATABACKUP MIGRATOR)        " -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Cyan

    $pkg = Read-Host "`n[1] Masukkan Package Name (ketik 0 untuk keluar ke Launcher)`n(contoh: com.hottagames.nte)"
    if ($pkg -eq '0' -or [string]::IsNullOrWhiteSpace($pkg)) { exit }

    $uid = Get-UID -pkg $pkg
    if ($null -eq $uid) {
        Write-Host "[!] UID tidak ditemukan! Pastikan APK $pkg sudah terinstal." -ForegroundColor Red
        Pause
        continue
    }
    Write-Host " -> UID Terdeteksi: $uid" -ForegroundColor Green

    # --- LOOP KEDUA (LEVEL DIREKTORI/FOLDER) ---
    while ($true) {
        Write-Host "`n=======================================================" -ForegroundColor DarkGray
        Write-Host " [ TARGET AKTIF: $pkg | UID: $uid ]" -ForegroundColor Yellow
        Write-Host "=======================================================" -ForegroundColor DarkGray

        Write-Host "`n[2] Drag & Drop folder hasil ekstrak dari SSD ke sini" -ForegroundColor White
        Write-Host "    (Atau ketik 0 jika semua folder untuk game ini sudah selesai)" -ForegroundColor DarkGray
        $sourcePath = Read-Host "Path Folder"
        
        # Keluar dari Loop Direktori, kembali ke Loop Aplikasi
        if ($sourcePath -eq '0') { break } 
        
        $sourcePath = $sourcePath -replace '"', ''

        if (!(Test-Path $sourcePath)) {
            Write-Host "[!] Folder tidak ditemukan di PC. Coba lagi." -ForegroundColor Red
            continue
        }

        Write-Host "`n[3] Pilih Target Partisi di HP:" -ForegroundColor Cyan
        Write-Host " [1] /data/data/$pkg (Untuk USER / USER_DE)"
        Write-Host " [2] /data/media/0/Android/data/$pkg (Untuk DATA Eksternal)"
        Write-Host " [3] /data/media/0/Android/obb/$pkg (Untuk OBB Game)"
        Write-Host " [4] /data/media/0/Android/media/$pkg (Untuk MEDIA)"
        $targetChoice = Read-Host "Pilih nomor (1-4)"

        $targetDest = ""
        switch ($targetChoice) {
            '1' { $targetDest = "/data/data/$pkg" }
            '2' { $targetDest = "/data/media/0/Android/data/$pkg" }
            '3' { $targetDest = "/data/media/0/Android/obb/$pkg" }
            '4' { $targetDest = "/data/media/0/Android/media/$pkg" }
            default { Write-Host "[!] Pilihan tidak valid."; continue }
        }

        Write-Host "`n[*] MEMULAI PROSES DIRECT PUSH..." -ForegroundColor Yellow
        Write-Host "    Dari : $sourcePath"
        Write-Host "    Ke   : $targetDest"
        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray

        # Mendorong isi folder secara langsung
        cmd.exe /c "adb push `"$sourcePath\.`" `"$targetDest/`""

        Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[*] Mengunci Permission (chown -R ${uid}:${uid})..." -ForegroundColor Yellow
        adb shell "chown -R ${uid}:${uid} $targetDest 2>/dev/null"

        Write-Host "`n[OK] INJEKSI DIREKTORI SELESAI!" -ForegroundColor Green
        Write-Host "Silakan masukkan path folder berikutnya untuk game ini." -ForegroundColor Cyan
    }
}