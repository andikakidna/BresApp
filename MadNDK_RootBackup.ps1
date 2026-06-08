$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = (Get-Location).Path }
$BackupRoot = "$ScriptDir\Backup\apps"

function Wait-AdbConnection {
    while ($true) {
        $adbState = [string](adb get-state 2>$null)
        if ($adbState -match 'device') { 
            $devices = [string](adb devices)
            if ($devices -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+") {
                Write-Host "  -> [OK] Terhubung via Wireless ADB!" -ForegroundColor Green
            } else {
                Write-Host "  -> [OK] Terhubung via Kabel USB!" -ForegroundColor Green
            }
            return $true 
        }
        Write-Host "`n[!] KONEKSI ADB TERPUTUS ATAU DEVICE TIDAK READY!" -ForegroundColor Red
        Write-Host "Pilih metode koneksi perangkat:" -ForegroundColor Yellow
        Write-Host " [ENTER] Deteksi ulang Kabel USB" -ForegroundColor White
        Write-Host " [W]     Hubungkan via Wireless Debugging (WIFI)" -ForegroundColor Cyan
        Write-Host " [0]     Batal dan Keluar" -ForegroundColor DarkGray
        $retry = Read-Host "`nMasukkan pilihan"
        if ($retry -eq '0') { return $false }
        if ($retry -match '^[Ww]$') {
            Write-Host "`n[*] MENGINISIASI KONEKSI WIRELESS DEBUGGING..." -ForegroundColor Cyan
            $ipPort = Read-Host "`nMasukkan [Alamat IP]:[Port] (Contoh: 192.168.1.15:43215)"
            if (![string]::IsNullOrWhiteSpace($ipPort)) {
                $connectResult = [string](cmd.exe /c "adb connect $ipPort 2>&1")
                if ($connectResult -match "connected to") {
                    Write-Host "[+] Koneksi Nirkabel Berhasil Dikunci!" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                } else {
                    Write-Host "[-] Gagal terhubung: $connectResult" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
        }
    }
}

function Check-RootAccess {
    Write-Host "`n[*] Memeriksa akses Root (KernelSU)..." -ForegroundColor Cyan
    Write-Host "    [!] PERHATIAN: Buka KernelSU Manager -> Tab Superuser -> Izinkan 'Shell'" -ForegroundColor Yellow
    $rootCheck = [string](adb shell "su -c 'id' 2>/dev/null").Trim()
    if ($rootCheck -match "uid=0") {
        Write-Host "    -> [OK] Akses Root Diberikan!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "    -> [GAGAL] ADB Shell belum mendapat izin Root di KSU!" -ForegroundColor Red
        Pause; return $false
    }
}

function Show-BackupMenu {
    Clear-Host
    Write-Host '=======================================================' -ForegroundColor Red
    Write-Host '   MADNDK MULTI-BACKUP ENGINE (KERNELSU ROOT EDITION)  ' -ForegroundColor Yellow
    Write-Host '         Version 2.0 (Wireless ^| Live OS List)        ' -ForegroundColor DarkGray
    Write-Host '=======================================================' -ForegroundColor Red
    
    if (!(Wait-AdbConnection)) { return }
    if (!(Check-RootAccess)) { return }
    
    Write-Host "`n[*] Membaca daftar aplikasi pihak ketiga di perangkat..." -ForegroundColor Cyan
    $rawApps = adb shell "su -c 'pm list packages -3'"
    $installedApps = $rawApps -split "`n" | ForEach-Object { $_ -replace 'package:', '' -replace "`r", "" } | Where-Object { $_ -match '\S' } | Sort-Object
    
    if ($installedApps.Count -eq 0) {
        Write-Host "[!] Tidak ada aplikasi pihak ketiga yang terdeteksi." -ForegroundColor Red
        Pause; return
    }
    
    Write-Host "`n[ DAFTAR APLIKASI YANG DAPAT DI-BACKUP ]" -ForegroundColor Yellow
    $i = 1
    foreach ($app in $installedApps) {
        Write-Host " [$i] $app"
        $i++
    }
    Write-Host '=======================================================' -ForegroundColor Red
    Write-Host ' [0] Keluar ke Toolkit'
    
    $appChoice = Read-Host "`nMasukkan indeks target (Format multi: 1, 3, 5)"
    if ($appChoice -eq '0' -or [string]::IsNullOrWhiteSpace($appChoice)) { return }
    
    $selectedIndices = $appChoice -split '[,; ]' | Where-Object { $_ -match '\d+' } | ForEach-Object { [int]$_ - 1 }
    $validPkgs = @()
    foreach ($idx in $selectedIndices) {
        if ($idx -ge 0 -and $idx -lt $installedApps.Count) { $validPkgs += $installedApps[$idx] }
    }
    
    if ($validPkgs.Count -gt 0) {
        foreach ($pkg in $validPkgs) { Process-Backup -pkg $pkg }
        Write-Host "`n[+] BATCH MULTI-BACKUP SAKTI SELESAI!" -ForegroundColor Green
        Pause
    }
    Show-BackupMenu
}

function Process-Backup {
    param ([string]$pkg)
    $DestFolder = "$BackupRoot\$pkg\user_0"
    New-Item -ItemType Directory -Force -Path $DestFolder | Out-Null
    
    Write-Host "`n=======================================================" -ForegroundColor DarkGray
    Write-Host "[*] PROSES PROTOKOL BACKUP: $pkg" -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor DarkGray
    
    $apkCheck = [string](adb shell "su -c 'ls -d /data/app/*/$pkg-* 2>/dev/null' | head -n 1").Trim()
    
    function Get-TimeStr($sw) {
        $e = $sw.Elapsed
        return "{0:00} Menit {1:00} Detik" -f $e.Minutes, $e.Seconds
    }
    
    function Backup-TarMode {
        param ($SourcePath, $TarName, $Label)
        $check = [string](adb shell "su -c 'ls -d $SourcePath 2>/dev/null'").Trim()
        if ($check -match "No such file" -or $check -eq "") { return }
        Write-Host "  - Mem-backup $Label... (Format: TAR) " -NoNewline -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        cmd.exe /c "adb exec-out `"su -c 'tar -cf - -C $SourcePath .' `" > `"$DestFolder\$TarName`""
        $sw.Stop()
        Write-Host "($(Get-TimeStr $sw))" -ForegroundColor Green
    }
    
    function Backup-FolderMode {
        param ($SourcePath, $FolderName, $Label)
        $check = [string](adb shell "su -c 'ls -d $SourcePath 2>/dev/null'").Trim()
        if ($check -match "No such file" -or $check -eq "") { return }
        Write-Host "  - Mem-backup $Label... (Format: RAW FOLDER)" -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $TargetFolder = "$DestFolder\$FolderName"
        if (Test-Path $TargetFolder) { Remove-Item $TargetFolder -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $TargetFolder | Out-Null
        cmd.exe /c "adb pull `"$SourcePath/.`" `"$TargetFolder`" >nul 2>&1"
        $sw.Stop()
        Write-Host "    -> Pull Folder Selesai ($(Get-TimeStr $sw))" -ForegroundColor Green
    }
    
    if ($apkCheck -notmatch "No such file" -and $apkCheck -ne "") { Backup-TarMode $apkCheck "apk.tar" "[APK]" }
    Backup-TarMode "/data/data/$pkg" "user.tar" "[USER]"
    Backup-TarMode "/data/user_de/0/$pkg" "user_de.tar" "[USER_DE]"
    Backup-FolderMode "/data/media/0/Android/media/$pkg" "media" "[MEDIA]"
    Backup-TarMode "/data/media/0/Android/data/$pkg" "data.tar" "[DATA]"
    Backup-TarMode "/data/media/0/Android/obb/$pkg" "obb.tar" "[OBB]"
    
    Write-Host "[OK] Backup Komplit untuk -> $pkg" -ForegroundColor Green
}

Show-BackupMenu