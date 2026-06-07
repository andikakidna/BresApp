$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = (Get-Location).Path }
$BackupRoot = "$ScriptDir\Backup\apps"
$QueueFile = "$ScriptDir\pending_restore.txt"

function Wait-AdbConnection {
    while ($true) {
        $adbState = [string](adb get-state 2>$null)
        if ($adbState -match 'device|recovery') { return $true }
        
        Write-Host "`n[!] KONEKSI ADB TERPUTUS ATAU PERANGKAT TIDAK TERDETEKSI!" -ForegroundColor Red
        Write-Host 'Pastikan kabel terhubung dan posisi perangkat di Recovery.' -ForegroundColor Yellow
        $retry = Read-Host 'Tekan [ENTER] untuk mencoba ulang, atau ketik [0] untuk batal'
        if ($retry -eq '0') { return $false }
    }
}

function Check-MountStatus {
    while ($true) {
        if (!(Wait-AdbConnection)) { return $false }
        $checkMount = [string](adb shell "ls /data/app 2>/dev/null")
        if ($checkMount -match "~~" -or $checkMount -match "com\.") { return $true }
        
        Write-Host "`n[!] KEGAGALAN KRITIS: PARTISI DATA BELUM DI-MOUNT!" -ForegroundColor Red
        Write-Host "Silakan masuk ke menu 'Mount' di TWRP/OrangeFox dan centang partisi 'Data'." -ForegroundColor Yellow
        $retry = Read-Host "Tekan [ENTER] jika sudah di-mount untuk mencoba lagi, atau ketik [0] untuk batal"
        if ($retry -eq '0') { return $false }
    }
}

function Show-MainMenu {
    Clear-Host
    Write-Host '=======================================================' -ForegroundColor Cyan
    Write-Host '  MADNDK RESTORE PHASE 2: DATA RECOVERY (RECOVERY)     ' -ForegroundColor Yellow
    Write-Host '    Version 1.0 (Auto-Folder Detect & Deep Mapping)    ' -ForegroundColor DarkGray
    Write-Host '=======================================================' -ForegroundColor Cyan
    
    if (Test-Path $QueueFile) {
        $pendingPkgs = Get-Content $QueueFile | Where-Object { $_ -match '\S' }
        if ($pendingPkgs.Count -gt 0) {
            Write-Host "`n[MADNDK-SYNC] Antrean Auto-Sync dari Phase 1 terdeteksi:" -ForegroundColor Green
            foreach ($p in $pendingPkgs) { Write-Host " - $p" -ForegroundColor White }
            
            $autoConfirm = Read-Host "`nEksekusi pemulihan data untuk daftar di atas? [Y/N]"
            if ($autoConfirm -match '^[Yy]$') {
                if (!(Check-MountStatus)) { return }
                foreach ($pkg in $pendingPkgs) { Process-Phase2 -pkg $pkg }
                Remove-Item $QueueFile -Force
                Write-Host "`n[+] BATCH AUTO-SYNC SELESAI!" -ForegroundColor Green
                
                $rebootChoice = Read-Host "`n[?] Injeksi selesai. Reboot ke System (OS) sekarang? [Y/N]"
                if ($rebootChoice -match '^[Yy]$') {
                    Write-Host "[*] Mengeksekusi Reboot System..." -ForegroundColor Cyan
                    adb reboot
                    exit
                }
                Pause; return
            }
        }
    }

    $backedUpApps = Get-ChildItem -Path $BackupRoot -Directory | Select-Object -ExpandProperty Name
    $i = 1
    foreach ($app in $backedUpApps) { Write-Host " [$i] $app"; $i++ }
    Write-Host '=======================================================' -ForegroundColor Cyan
    Write-Host ' [0] Keluar ke Toolkit'
    
    $appChoice = Read-Host 'Masukkan indeks target (Format: 1, 3, 5)'
    if ($appChoice -eq '0') { return }
    
    $selectedIndices = $appChoice -split '[,; ]' | Where-Object { $_ -match '\d+' } | ForEach-Object { [int]$_ - 1 }
    $validPkgs = @()
    foreach ($idx in $selectedIndices) {
        if ($idx -ge 0 -and $idx -lt $backedUpApps.Count) { $validPkgs += $backedUpApps[$idx] }
    }

    if ($validPkgs.Count -gt 0) {
        if (!(Check-MountStatus)) { return }
        foreach ($pkg in $validPkgs) { Process-Phase2 -pkg $pkg }
        Write-Host "`n[+] BATCH MANUAL SELESAI!" -ForegroundColor Green
        
        $rebootChoice = Read-Host "`n[?] Injeksi selesai. Reboot ke System (OS) sekarang? [Y/N]"
        if ($rebootChoice -match '^[Yy]$') {
            Write-Host "[*] Mengeksekusi Reboot System..." -ForegroundColor Cyan
            adb reboot
            exit
        }
        Pause
    }
    Show-MainMenu
}

function Process-Phase2 {
    param ([string]$pkg)
    $SourceFolder = "$BackupRoot\$pkg\user_0"
    
    $newUid = [string](adb shell "stat -c %u /data/data/$pkg 2>/dev/null")
    $newUid = $newUid.Trim()
    
    if ([string]::IsNullOrEmpty($newUid) -or $newUid -match "No such file") {
        Write-Host "`n[*] MENGEKSEKUSI RECOVERY: $pkg" -ForegroundColor Yellow
        Write-Host "  -> [!] Gagal: Paket belum diinstal di OS (UID Hilang). Lewati..." -ForegroundColor Red
        return
    }

    Write-Host "`n[*] MENGEKSEKUSI RECOVERY: $pkg (UID: $newUid)" -ForegroundColor Yellow

    function Get-TimeStr($sw) {
        $e = $sw.Elapsed
        $t = "{0:00} Menit {1:00} Detik" -f $e.Minutes, $e.Seconds
        if ($e.Hours -gt 0) { $t = "{0:00} Jam " -f $e.Hours + $t }
        return $t
    }

    # MODE 1: RAW FOLDER (Bypass Ekstraksi)
    function Restore-FolderMode {
        param ($FolderPath, $DestPath, $Label)
        Write-Host "  - Memulihkan direktori $Label... (Format: RAW FOLDER)" -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        $targetPushDir = $FolderPath
        $deepFolder = Get-ChildItem -Path $FolderPath -Recurse -Directory | Where-Object { $_.Name -eq $pkg } | Select-Object -First 1
        
        if ($null -ne $deepFolder) {
            $targetPushDir = $deepFolder.FullName
            Write-Host "    -> Struktur terpetakan otomatis, mendorong data inti..." -ForegroundColor DarkGray
        } else {
            Write-Host "    -> Struktur flat, mendorong isi folder..." -ForegroundColor DarkGray
        }
        
        adb shell "mkdir -p $DestPath"
        cmd.exe /c "adb push `"$targetPushDir\.`" `"$DestPath/`" >nul 2>&1"
        
        $sw.Stop()
        Write-Host "    -> Injeksi Langsung Selesai ($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    # MODE 2: TAR MURNI
    function Restore-TarMode {
        param ($TarPath, $Label)
        Write-Host "  - Memulihkan direktori $Label... (Format: TAR) " -NoNewline -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        cmd.exe /c "adb exec-in `"tar -xf - -C /`" < `"$TarPath`""
        $sw.Stop()
        Write-Host "($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    # MODE 3: ZSTD (Ekstrak Temp)
    function Restore-ZstMode {
        param ($ZstPath, $DestPath, $Label)
        Write-Host "  - Memulihkan direktori $Label... (Format: ZSTD)" -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        $TempExt = "$ScriptDir\TempZstExt_$pkg"
        if (Test-Path $TempExt) { Remove-Item $TempExt -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $TempExt | Out-Null
        
        Start-Process -FilePath "tar" -ArgumentList "-xf `"$ZstPath`" -C `"$TempExt`"" -Wait -NoNewWindow
        
        $targetPushDir = $TempExt
        $deepFolder = Get-ChildItem -Path $TempExt -Recurse -Directory | Where-Object { $_.Name -eq $pkg } | Select-Object -First 1
        
        if ($null -ne $deepFolder) {
            $targetPushDir = $deepFolder.FullName
            Write-Host "    -> Struktur terpetakan, mendorong data inti..." -ForegroundColor DarkGray
        }
        
        adb shell "mkdir -p $DestPath"
        cmd.exe /c "adb push `"$targetPushDir\.`" `"$DestPath/`" >nul 2>&1"
        Remove-Item $TempExt -Recurse -Force
        
        $sw.Stop()
        Write-Host "    -> Ekstraksi & Push Selesai ($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    # ================= LOGIKA PRIORITAS KASTA =================

    # PROSES USER
    if (Test-Path "$SourceFolder\user" -PathType Container) { Restore-FolderMode "$SourceFolder\user" "/data/data/$pkg" "[USER]" }
    elseif (Test-Path "$SourceFolder\user.tar" -PathType Leaf) { Restore-TarMode "$SourceFolder\user.tar" "[USER]" }
    elseif (Test-Path "$SourceFolder\user.tar.zst" -PathType Leaf) { Restore-ZstMode "$SourceFolder\user.tar.zst" "/data/data/$pkg" "[USER]" }
    adb shell "chown -R ${newUid}:${newUid} /data/data/$pkg 2>/dev/null"
    adb shell "restorecon -RF /data/data/$pkg 2>/dev/null"

    # PROSES USER_DE
    if (Test-Path "$SourceFolder\user_de" -PathType Container) { Restore-FolderMode "$SourceFolder\user_de" "/data/user_de/0/$pkg" "[USER_DE]" }
    elseif (Test-Path "$SourceFolder\user_de.tar" -PathType Leaf) { Restore-TarMode "$SourceFolder\user_de.tar" "[USER_DE]" }
    elseif (Test-Path "$SourceFolder\user_de.tar.zst" -PathType Leaf) { Restore-ZstMode "$SourceFolder\user_de.tar.zst" "/data/user_de/0/$pkg" "[USER_DE]" }
    adb shell "chown -R ${newUid}:${newUid} /data/user_de/0/$pkg 2>/dev/null"
    adb shell "restorecon -RF /data/user_de/0/$pkg 2>/dev/null"

    # PROSES MEDIA
    if (Test-Path "$SourceFolder\media" -PathType Container) { Restore-FolderMode "$SourceFolder\media" "/data/media/0/Android/media/$pkg" "[MEDIA]" }
    elseif (Test-Path "$SourceFolder\media.tar" -PathType Leaf) { Restore-TarMode "$SourceFolder\media.tar" "[MEDIA]" }
    elseif (Test-Path "$SourceFolder\media.tar.zst" -PathType Leaf) { Restore-ZstMode "$SourceFolder\media.tar.zst" "/data/media/0/Android/media/$pkg" "[MEDIA]" }
    adb shell "chown -R ${newUid}:${newUid} /data/media/0/Android/media/$pkg 2>/dev/null"
    adb shell "restorecon -RF /data/media/0/Android/media/$pkg 2>/dev/null"

    # PROSES DATA EKSTERNAL (GAMES)
    if (Test-Path "$SourceFolder\data" -PathType Container) { Restore-FolderMode "$SourceFolder\data" "/data/media/0/Android/data/$pkg" "[DATA]" }
    elseif (Test-Path "$SourceFolder\data.tar" -PathType Leaf) { Restore-TarMode "$SourceFolder\data.tar" "[DATA]" }
    elseif (Test-Path "$SourceFolder\data.tar.zst" -PathType Leaf) { Restore-ZstMode "$SourceFolder\data.tar.zst" "/data/media/0/Android/data/$pkg" "[DATA]" }
    adb shell "chown -R ${newUid}:${newUid} /data/media/0/Android/data/$pkg 2>/dev/null"
    adb shell "restorecon -RF /data/media/0/Android/data/$pkg 2>/dev/null"

    # PROSES OBB
    if (Test-Path "$SourceFolder\obb" -PathType Container) { Restore-FolderMode "$SourceFolder\obb" "/data/media/0/Android/obb/$pkg" "[OBB]" }
    elseif (Test-Path "$SourceFolder\obb.tar" -PathType Leaf) { Restore-TarMode "$SourceFolder\obb.tar" "[OBB]" }
    elseif (Test-Path "$SourceFolder\obb.tar.zst" -PathType Leaf) { Restore-ZstMode "$SourceFolder\obb.tar.zst" "/data/media/0/Android/obb/$pkg" "[OBB]" }
    adb shell "chown -R ${newUid}:${newUid} /data/media/0/Android/obb/$pkg 2>/dev/null"
    adb shell "restorecon -RF /data/media/0/Android/obb/$pkg 2>/dev/null"

    # PEMBERSIHAN CACHE & DIREKTORI SEMENTARA
    adb shell "rm -rf /data/data/$pkg/cache/* 2>/dev/null"
    adb shell "rm -rf /data/local/tmp/MadNDK* 2>/dev/null"

    Write-Host "  -> [OK] Status injeksi data & SELinux berhasil.`n" -ForegroundColor Green
}

Show-MainMenu