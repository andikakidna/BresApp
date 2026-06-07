$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = (Get-Location).Path }
$BackupRoot = "$ScriptDir\Backup\apps"

function Wait-AdbConnection {
    while ($true) {
        $adbState = [string](adb get-state 2>$null)
        if ($adbState -match 'device|recovery') { return $true }
        
        Write-Host "`n[!] KONEKSI ADB TERPUTUS ATAU PERANGKAT TIDAK TERDETEKSI!" -ForegroundColor Red
        Write-Host 'Pastikan kabel terhubung dan posisi perangkat di Recovery/OS.' -ForegroundColor Yellow
        $retry = Read-Host 'Tekan [ENTER] untuk mencoba ulang, atau ketik [0] untuk batal'
        if ($retry -eq '0') { return $false }
    }
}

function Show-BackupMenu {
    Clear-Host
    Write-Host '=======================================================' -ForegroundColor Cyan
    Write-Host '      MADNDK SYSTEM BACKUP (TAR & FOLDER HYBRID)       ' -ForegroundColor Yellow
    Write-Host '           Version 1.0 (Smart Media Extractor)         ' -ForegroundColor DarkGray
    Write-Host '=======================================================' -ForegroundColor Cyan
    Write-Host "`n[1] Mulai Backup Aplikasi/Game Baru"
    Write-Host "    (Contoh input: com.whatsapp, com.mobile.legends)"
    Write-Host '-------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ' [0] Keluar ke Toolkit'
    
    $choice = Read-Host "`nMasukkan pilihan"
    if ($choice -eq '0') { return }
    if ($choice -eq '1') {
        if (!(Wait-AdbConnection)) { return }
        $pkg = Read-Host "Masukkan Package Name target"
        if (![string]::IsNullOrWhiteSpace($pkg)) { Process-Backup -pkg $pkg.Trim() }
    }
    Show-BackupMenu
}

function Process-Backup {
    param ([string]$pkg)
    $DestFolder = "$BackupRoot\$pkg\user_0"
    
    # Cek ketersediaan aplikasi di sistem (mencari folder app)
    $apkCheck = [string](adb shell "ls -d /data/app/*/$pkg-* 2>/dev/null | head -n 1").Trim()
    $dataCheck = [string](adb shell "ls -d /data/data/$pkg 2>/dev/null").Trim()
    
    if ($dataCheck -match "No such file" -and $apkCheck -match "No such file") {
        Write-Host "`n[!] Paket $pkg tidak ditemukan di dalam sistem!" -ForegroundColor Red
        Pause; return
    }

    New-Item -ItemType Directory -Force -Path $DestFolder | Out-Null
    Write-Host "`n[*] MEMULAI PROSES BACKUP: $pkg" -ForegroundColor Yellow

    function Get-TimeStr($sw) {
        $e = $sw.Elapsed
        $t = "{0:00} Menit {1:00} Detik" -f $e.Minutes, $e.Seconds
        if ($e.Hours -gt 0) { $t = "{0:00} Jam " -f $e.Hours + $t }
        return $t
    }

    # MESIN PEMBUAT TAR (Untuk APK, USER, DATA, OBB)
    function Backup-TarMode {
        param ($SourcePath, $TarName, $Label)
        $check = [string](adb shell "ls -d $SourcePath 2>/dev/null").Trim()
        if ($check -match "No such file" -or $check -eq "") { return }
        
        Write-Host "  - Mem-backup $Label... (Format: TAR) " -NoNewline -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        cmd.exe /c "adb exec-out `"tar -cf - -C $SourcePath .`" > `"$DestFolder\$TarName`""
        $sw.Stop()
        Write-Host "($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    # MESIN PENARIK FOLDER UTUH (Khusus untuk MEDIA)
    function Backup-FolderMode {
        param ($SourcePath, $FolderName, $Label)
        $check = [string](adb shell "ls -d $SourcePath 2>/dev/null").Trim()
        if ($check -match "No such file" -or $check -eq "") { return }

        Write-Host "  - Mem-backup $Label... (Format: RAW FOLDER)" -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        $TargetFolder = "$DestFolder\$FolderName"
        if (Test-Path $TargetFolder) { Remove-Item $TargetFolder -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $TargetFolder | Out-Null
        
        # Pull langsung isi foldernya (pakai /. agar tidak inception)
        cmd.exe /c "adb pull `"$SourcePath/.`" `"$TargetFolder`" >nul 2>&1"
        
        $sw.Stop()
        Write-Host "    -> Pull Folder Selesai ($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    # 1. BACKUP APK (Mencari folder acak base64 di Android 12+)
    if ($apkCheck -notmatch "No such file" -and $apkCheck -ne "") {
        Backup-TarMode $apkCheck "apk.tar" "[APK]"
    }

    # 2. BACKUP USER & USER_DE (Format TAR)
    Backup-TarMode "/data/data/$pkg" "user.tar" "[USER]"
    Backup-TarMode "/data/user_de/0/$pkg" "user_de.tar" "[USER_DE]"

    # 3. BACKUP MEDIA (Format FOLDER UTUH - Request Khusus)
    Backup-FolderMode "/data/media/0/Android/media/$pkg" "media" "[MEDIA]"

    # 4. BACKUP DATA & OBB (Format TAR)
    Backup-TarMode "/data/media/0/Android/data/$pkg" "data.tar" "[DATA]"
    Backup-TarMode "/data/media/0/Android/obb/$pkg" "obb.tar" "[OBB]"

    Write-Host "`n[OK] PROSES BACKUP HYBRID SELESAI!" -ForegroundColor Green
    Write-Host "Tersimpan di: $DestFolder" -ForegroundColor DarkGray
    Pause
}

Show-BackupMenu