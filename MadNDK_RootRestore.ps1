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

function Show-RestoreMenu {
    Clear-Host
    Write-Host '=======================================================' -ForegroundColor Red
    Write-Host '  MADNDK MULTI-RESTORE ENGINE (KERNELSU ROOT EDITION)  ' -ForegroundColor Yellow
    Write-Host '       Version 2.0 (All-In-One Wireless Injector)      ' -ForegroundColor DarkGray
    Write-Host '=======================================================' -ForegroundColor Red
    
    $backedUpApps = Get-ChildItem -Path $BackupRoot -Directory | Select-Object -ExpandProperty Name
    if ($backedUpApps.Count -eq 0) {
        Write-Host "[!] Folder Backup\apps kosong!" -ForegroundColor Red
        Pause; return
    }
    
    $i = 1
    foreach ($app in $backedUpApps) { Write-Host " [$i] $app"; $i++ }
    Write-Host '=======================================================' -ForegroundColor Red
    Write-Host ' [0] Keluar ke Toolkit'
    
    $appChoice = Read-Host "`nMasukkan indeks target (Format multi: 1, 3, 5)"
    if ($appChoice -eq '0' -or [string]::IsNullOrWhiteSpace($appChoice)) { return }
    
    $selectedIndices = $appChoice -split '[,; ]' | Where-Object { $_ -match '\d+' } | ForEach-Object { [int]$_ - 1 }
    $validPkgs = @()
    foreach ($idx in $selectedIndices) {
        if ($idx -ge 0 -and $idx -lt $backedUpApps.Count) { $validPkgs += $backedUpApps[$idx] }
    }

    if ($validPkgs.Count -gt 0) {
        if (!(Wait-AdbConnection)) { return }
        if (!(Check-RootAccess)) { return }
        
        foreach ($pkg in $validPkgs) { Process-RootRestore -pkg $pkg }
        Write-Host "`n[+] BATCH DEPLOYMENT ROOT SELESAI!" -ForegroundColor Green
        Pause
    }
    Show-RestoreMenu
}

function Process-RootRestore {
    param ([string]$pkg)
    $SourceFolder = "$BackupRoot\$pkg\user_0"
    
    Write-Host "`n=======================================================" -ForegroundColor DarkGray
    Write-Host "[*] INJEKSI PROTOKOL RESTORE: $pkg" -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor DarkGray

    # FASE 1: INSTALASI APK (Mendukung Folder & Tar)
    $TargetApkDir = ""
    if (Test-Path "$SourceFolder\apk" -PathType Container) {
        $TargetApkDir = "$SourceFolder\apk"
        Write-Host "  -> Mode Folder Terbuka terdeteksi." -ForegroundColor Cyan
    } elseif (Test-Path "$SourceFolder\apk.tar") {
        $TempExt = "$ScriptDir\TempApkExt_$pkg"
        if (Test-Path $TempExt) { Remove-Item $TempExt -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $TempExt | Out-Null
        Start-Process -FilePath "tar" -ArgumentList "-xf `"$SourceFolder\apk.tar`" -C `"$TempExt`"" -Wait -NoNewWindow
        $TargetApkDir = $TempExt
    }

    if ($TargetApkDir -ne "") {
        $apkFiles = Get-ChildItem -Path $TargetApkDir -Recurse -Filter "*.apk" | Select-Object -ExpandProperty FullName
        if ($apkFiles.Count -gt 0) {
            Write-Host "  -> Menginstal APK (Bypass Play Store)..." -ForegroundColor Cyan
            $installArgs = "install-multiple -r -d -i com.android.vending"
            foreach ($apk in $apkFiles) { $installArgs += " `"$apk`"" }
            cmd.exe /c "adb $installArgs >nul 2>&1"
        }
        if (Test-Path "$ScriptDir\TempApkExt_$pkg") { Remove-Item "$ScriptDir\TempApkExt_$pkg" -Recurse -Force }
    }

    # AMBIL UID BARU
    $newUid = [string](adb shell "su -c 'stat -c %u /data/data/$pkg 2>/dev/null'").Trim()
    if ([string]::IsNullOrEmpty($newUid) -or $newUid -match "No such file") {
        Write-Host "  -> [!] Aplikasi belum terinstal. Injeksi dibatalkan." -ForegroundColor Red
        return
    }
    Write-Host "  -> UID Terkunci: $newUid" -ForegroundColor Green

    # FASE 2: INJEKSI DATA & PERBAIKAN SELINUX VIA KSU
    function Get-TimeStr($sw) {
        $e = $sw.Elapsed
        return "{0:00} Menit {1:00} Detik" -f $e.Minutes, $e.Seconds
    }

    function Restore-FolderMode {
        param ($FolderPath, $DestPath, $Label)
        Write-Host "  - Memulihkan direktori $Label... (RAW FOLDER)" -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $targetPushDir = $FolderPath
        $deepFolder = Get-ChildItem -Path $FolderPath -Recurse -Directory | Where-Object { $_.Name -eq $pkg } | Select-Object -First 1
        if ($null -ne $deepFolder) { $targetPushDir = $deepFolder.FullName }
        
        adb shell "su -c 'mkdir -p $DestPath'"
        cmd.exe /c "adb push `"$targetPushDir\.`" `"/sdcard/TempMadNDK_$pkg/`" >nul 2>&1"
        adb shell "su -c 'cp -r /sdcard/TempMadNDK_$pkg/* $DestPath/ && rm -rf /sdcard/TempMadNDK_$pkg'"
        $sw.Stop()
        Write-Host "    -> Injeksi Selesai ($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    function Restore-TarMode {
        param ($TarPath, $Label)
        Write-Host "  - Memulihkan direktori $Label... (TAR) " -NoNewline -ForegroundColor Cyan
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        cmd.exe /c "adb exec-in `"tar -xf - -C /`" < `"$TarPath`""
        $sw.Stop()
        Write-Host "($(Get-TimeStr $sw))" -ForegroundColor Green
    }

    if (Test-Path "$SourceFolder\user" -PathType Container) { Restore-FolderMode "$SourceFolder\user" "/data/data/$pkg" "[USER]" }
    elseif (Test-Path "$SourceFolder\user.tar") { Restore-TarMode "$SourceFolder\user.tar" "[USER]" }
    adb shell "su -c 'chown -R ${newUid}:${newUid} /data/data/$pkg 2>/dev/null'"
    adb shell "su -c 'restorecon -RF /data/data/$pkg 2>/dev/null'"

    if (Test-Path "$SourceFolder\user_de" -PathType Container) { Restore-FolderMode "$SourceFolder\user_de" "/data/user_de/0/$pkg" "[USER_DE]" }
    elseif (Test-Path "$SourceFolder\user_de.tar") { Restore-TarMode "$SourceFolder\user_de.tar" "[USER_DE]" }
    adb shell "su -c 'chown -R ${newUid}:${newUid} /data/user_de/0/$pkg 2>/dev/null'"
    adb shell "su -c 'restorecon -RF /data/user_de/0/$pkg 2>/dev/null'"

    if (Test-Path "$SourceFolder\media" -PathType Container) { Restore-FolderMode "$SourceFolder\media" "/data/media/0/Android/media/$pkg" "[MEDIA]" }
    elseif (Test-Path "$SourceFolder\media.tar") { Restore-TarMode "$SourceFolder\media.tar" "[MEDIA]" }
    adb shell "su -c 'chown -R ${newUid}:${newUid} /data/media/0/Android/media/$pkg 2>/dev/null'"
    adb shell "su -c 'restorecon -RF /data/media/0/Android/media/$pkg 2>/dev/null'"

    if (Test-Path "$SourceFolder\data" -PathType Container) { Restore-FolderMode "$SourceFolder\data" "/data/media/0/Android/data/$pkg" "[DATA]" }
    elseif (Test-Path "$SourceFolder\data.tar") { Restore-TarMode "$SourceFolder\data.tar" "[DATA]" }
    adb shell "su -c 'chown -R ${newUid}:${newUid} /data/media/0/Android/data/$pkg 2>/dev/null'"
    adb shell "su -c 'restorecon -RF /data/media/0/Android/data/$pkg 2>/dev/null'"

    if (Test-Path "$SourceFolder\obb" -PathType Container) { Restore-FolderMode "$SourceFolder\obb" "/data/media/0/Android/obb/$pkg" "[OBB]" }
    elseif (Test-Path "$SourceFolder\obb.tar") { Restore-TarMode "$SourceFolder\obb.tar" "[OBB]" }
    adb shell "su -c 'chown -R ${newUid}:${newUid} /data/media/0/Android/obb/$pkg 2>/dev/null'"
    adb shell "su -c 'restorecon -RF /data/media/0/Android/obb/$pkg 2>/dev/null'"

    adb shell "su -c 'rm -rf /data/data/$pkg/cache/* 2>/dev/null'"
    Write-Host "[OK] Pemulihan Selesai untuk -> $pkg" -ForegroundColor Green
}

Show-RestoreMenu