$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = (Get-Location).Path }
$BackupRoot = "$ScriptDir\Backup\apps"
$QueueFile = "$ScriptDir\pending_restore.txt"

function Wait-AdbConnection {
    while ($true) {
        $adbState = [string](adb get-state 2>$null)
        if ($adbState -match 'device') { return $true }
        
        Write-Host "`n[!] KONEKSI ADB TERPUTUS ATAU DEVICE TIDAK READY!" -ForegroundColor Red
        Write-Host 'Pastikan OS menyala normal dan USB Debugging aktif.' -ForegroundColor Yellow
        $retry = Read-Host 'Tekan [ENTER] untuk mencoba ulang, atau ketik [0] untuk batal'
        if ($retry -eq '0') { return $false }
    }
}

function Show-Phase1Menu {
    Clear-Host
    Write-Host '=======================================================' -ForegroundColor Cyan
    Write-Host '  MADNDK RESTORE PHASE 1: PACKAGE DEPLOYMENT (OS)      ' -ForegroundColor Yellow
    Write-Host '   Version 1.0 (Temp-Bypass & Anti-DRM Play Store)     ' -ForegroundColor DarkGray
    Write-Host '=======================================================' -ForegroundColor Cyan
    
    $backedUpApps = Get-ChildItem -Path $BackupRoot -Directory | Select-Object -ExpandProperty Name
    $i = 1
    foreach ($app in $backedUpApps) { Write-Host " [$i] $app"; $i++ }
    Write-Host '=======================================================' -ForegroundColor Cyan
    Write-Host ' [0] Keluar ke Toolkit'
    
    $appChoice = Read-Host "`nMasukkan indeks target (Format: 1, 3, 5)"
    if ($appChoice -eq '0') { return }
    
    $selectedIndices = $appChoice -split '[,; ]' | Where-Object { $_ -match '\d+' } | ForEach-Object { [int]$_ - 1 }
    $validPkgs = @()
    foreach ($idx in $selectedIndices) {
        if ($idx -ge 0 -and $idx -lt $backedUpApps.Count) { $validPkgs += $backedUpApps[$idx] }
    }

    if ($validPkgs.Count -gt 0) {
        if (!(Wait-AdbConnection)) { return }
        $syncList = @()
        
        foreach ($pkg in $validPkgs) { 
            $status = Process-Phase1 -pkg $pkg 
            if ($status) { $syncList += $pkg }
        }
        
        if ($syncList.Count -gt 0) {
            $syncList | Out-File -FilePath $QueueFile -Encoding utf8 -Force
            Write-Host "`n[+] AUTO-SYNC QUEUE DIBUAT UNTUK PHASE 2!" -ForegroundColor Green
            
            $rebootChoice = Read-Host "`n[?] Phase 1 Selesai. Reboot ke Recovery (OrangeFox/TWRP) sekarang? [Y/N]"
            if ($rebootChoice -match '^[Yy]$') {
                Write-Host "[*] Mengeksekusi Reboot Recovery..." -ForegroundColor Cyan
                adb reboot recovery
                exit
            }
        }
        Pause
    }
    Show-Phase1Menu
}

function Process-Phase1 {
    param ([string]$pkg)
    $SourceFolder = "$BackupRoot\$pkg\user_0"
    Write-Host "`n[*] MENGEKSEKUSI INSTALASI: $pkg" -ForegroundColor Yellow

    $TargetApkDir = ""
    $TempExt = ""

    # CEK KASTA TERTINGGI: RAW FOLDER (Bypass Temp)
    if (Test-Path "$SourceFolder\apk" -PathType Container) {
        Write-Host "  -> Mode Folder Terbuka terdeteksi. Melewati ekstrak Temp..." -ForegroundColor Cyan
        $TargetApkDir = "$SourceFolder\apk"
    }
    # CEK KASTA KEDUA: FILE TAR
    elseif (Test-Path "$SourceFolder\apk.tar") {
        Write-Host "  -> Mengekstrak apk.tar ke Temp..." -ForegroundColor DarkGray
        $TempExt = "$ScriptDir\TempApkExt_$pkg"
        if (Test-Path $TempExt) { Remove-Item $TempExt -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $TempExt | Out-Null
        Start-Process -FilePath "tar" -ArgumentList "-xf `"$SourceFolder\apk.tar`" -C `"$TempExt`"" -Wait -NoNewWindow
        $TargetApkDir = $TempExt
    }
    else {
        Write-Host "  -> [!] File APK tidak ditemukan di backup. Lewati..." -ForegroundColor Red
        return $false
    }

    # MENCARI FILE .APK DI DALAM DIREKTORI TARGET
    $apkFiles = Get-ChildItem -Path $TargetApkDir -Recurse -Filter "*.apk" | Select-Object -ExpandProperty FullName
    
    if ($apkFiles.Count -eq 0) {
        Write-Host "  -> [!] Tidak ada file .apk yang valid untuk diinstal." -ForegroundColor Red
        if ($TempExt -ne "") { Remove-Item $TempExt -Recurse -Force }
        return $false
    }

    Write-Host "  -> Menginstal $($apkFiles.Count) file APK (Injeksi Anti-DRM Play Store)..." -ForegroundColor Cyan
    
    # PROSES INSTALASI MULTIPLE APK (Split APKs) DENGAN BYPASS PLAY STORE (-i com.android.vending)
    $installArgs = "install-multiple -r -d -i com.android.vending"
    foreach ($apk in $apkFiles) {
        $installArgs += " `"$apk`""
    }
    
    $installResult = cmd.exe /c "adb $installArgs 2>&1"
    
    # BERSIHKAN TEMP JIKA TADI MENGGUNAKAN MODE TAR
    if ($TempExt -ne "") { Remove-Item $TempExt -Recurse -Force }

    if ($installResult -match "Success") {
        Write-Host "  -> [OK] Instalasi Sukses!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  -> [!] Instalasi Gagal: $installResult" -ForegroundColor Red
        return $false
    }
}

Show-Phase1Menu