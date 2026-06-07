# 🚀 MadNDK System Deployment Toolkit v1.0 (Ultimate Edition)

Sebuah utilitas *Command-Line Interface* (CLI) berbasis Windows PowerShell dan ADB (Android Debug Bridge) yang dirancang khusus untuk melakukan *Backup* dan *Restore* data aplikasi/game Android berskala raksasa (AAA Games) secara mulus. 

Toolkit ini diciptakan untuk mengatasi limitasi penyimpanan internal (Zero Storage Overhead) dan melakukan injeksi data tanpa memerlukan akses **Root** di dalam sistem operasi utama (berjalan melalui jembatan TWRP/OrangeFox Recovery). Sangat cocok untuk pengguna *Custom ROM* (seperti crDroid) yang ingin menjaga OS tetap bersih dari Magisk/KernelSU demi keamanan aplikasi perbankan.

---

## ✨ Fitur Utama

*   **Direct-Stream Architecture:** Mentransfer file `.tar` murni melintasi kabel USB secara *real-time* langsung ke dalam sistem file Android tanpa perlu diekstrak di memori internal HP (mencegah *storage full* saat me-restore game 20GB+).
*   **Anti-DRM Play Store Bypass:** Menyuntikkan *installer* APK dengan sertifikasi palsu (`com.android.vending`), mencegah game *Live-Service* (seperti Neverness to Everness) meminta *download* ulang dari Play Store.
*   **Smart Folder Detection:** Mesin pintar yang mendeteksi dan mencegah anomali *Folder Inception* (folder ganda) saat mengekstrak arsip dari aplikasi pihak ketiga seperti *DataBackup*.
*   **Universal Auto-Sync Queue:** Sinkronisasi cerdas antara fase instalasi APK di OS (Phase 1) dengan injeksi data di Recovery (Phase 2).
*   **Stealth Mode:** Menyembunyikan seluruh tumpukan *error* bawaan PowerShell, memberikan antarmuka CLI yang bersih, rapi, dan transparan layaknya aplikasi *compiled binary*.
*   **Manual Pusher (Swiss Army Knife):** Modul ekstra untuk mendorong folder raksasa hasil dekompresi PC (SSD) secara manual dengan *progress bar* bawaan ADB.

---

## 📂 Struktur Modul

Toolkit ini terdiri dari 5 file utama:
1.  **`MadNDK_Toolkit.bat`** - *Launcher* utama dengan antarmuka ASCII Art.
2.  **`MadNDKBackup.ps1`** - Mesin *pull backup* (Sistem -> PC) dengan format TAR.
3.  **`MadNDKRestorePhase1_OS.ps1`** - Mesin instalasi APK (Dijalankan saat OS menyala).
4.  **`MadNDKRestorePhase2_Recovery.ps1`** - Mesin injeksi data (Dijalankan di TWRP/OrangeFox).
5.  **`MadNDK_ManualPusher.ps1`** - Modul injeksi folder manual untuk pemindahan data ekstrem.

---

## 🛠️ Persyaratan Sistem

*   OS Windows (10/11) dengan PowerShell terinstal.
*   ADB & Fastboot Drivers telah terkonfigurasi di *Environment Variables* Windows.
*   Perangkat Android dengan **USB Debugging** aktif.
*   **Custom Recovery** (TWRP atau OrangeFox) terinstal di perangkat.
*   Kabel data berkualitas tinggi (sangat disarankan untuk stabilitas transfer).

---

## 📖 Panduan Penggunaan Singkat

1.  Jalankan `MadNDK_Toolkit.bat`.
2.  **Untuk Backup:** Pilih menu `[1]` saat perangkat berada di mode Recovery dengan partisi `Data` di-mount.
3.  **Untuk Restore (Fase 1):** Pilih menu `[2]` saat OS menyala normal. Skrip akan menginstal APK dan membuat antrean data.
4.  **Untuk Restore (Fase 2):** Reboot ke Recovery, *mount* partisi `Data`, lalu pilih menu `[3]`. Data akan disuntikkan otomatis.
5.  **Untuk Migrasi Jumbo:** Gunakan menu `[4]` jika Anda mengekstrak file `.zst` raksasa secara manual di PC dan ingin memindahkannya dengan indikator kecepatan.