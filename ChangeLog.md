# 📝 Changelog: MadNDK System Deployment Toolkit

Semua perubahan penting pada proyek ini akan didokumentasikan di file ini.

## [v1.0] - Ultimate Edition
*   **ADDED:** ASCII Art UI di `MadNDK_Toolkit.bat` untuk tampilan *hacker-grade*.
*   **ADDED:** Modul ke-5: `MadNDK_ManualPusher.ps1` (Direct Injection).
*   **FEATURE:** Fitur Manual Pusher mendukung *drag-and-drop* path folder, pemilihan target partisi, dan penguncian UID otomatis (`chown -R`). Dibuat khusus untuk menangani proses migrasi dekompresi *game* raksasa di PC (memanfaatkan kecepatan SSD).

## [v0.7] - Smart Folder Fix
*   **FIXED:** Bug *Folder Inception* (folder beranak) saat melakukan *restore* dari arsip berformat `.zst` milik pihak ketiga.
*   **FEATURE:** Menambahkan logika *Smart Folder Detection* di Phase 2 yang akan menembus ke dalam direktori jika mendeteksi nama folder yang identik dengan nama *package*.

## [v0.6] - Direct Stream & UX
*   **CHANGED:** Menghapus dekompresi PC untuk format `.tar` murni (MadNDK Native). File sekarang langsung di- *stream* ke Android (*Zero Storage Overhead*).
*   **UI:** Merapikan tata letak informasi di layar Recovery, memindahkan deteksi UID ke bagian *header* eksekusi, dan menambahkan *Stopwatch* individual untuk setiap direktori.

## [v0.5] - Direct Push Architecture
*   **REMOVED:** Menghapus metode `exec-in` (I/O Redirection) yang rentan pecah akibat batas memori (Pipe Limit) saat menangani file di atas 10GB.
*   **FEATURE:** Menambahkan PC Decompression (`tar -xf` di Windows) khusus untuk file `.tar.zst` karena batasan utilitas `zstd` bawaan OrangeFox.
*   **UI:** Proses transfer sekarang memicu *Progress Bar* (persentase & MB/s) bawaan ADB ke layar CMD.

## [v0.4] - Stealth Edition
*   **UI/UX:** Menyembunyikan seluruh pesan *error stack-trace* (teks merah bawaan Windows) menggunakan parameter `$ErrorActionPreference = 'SilentlyContinue'`.
*   **FIXED:** *Parsing bug* pada ADB *State Checker* yang menyebabkan *crash* ketika membaca nilai *null*.

## [v0.3] - Final Polish
*   **FEATURE:** Menerapkan *Universal Retry System*. Kesalahan sepele (kabel goyang, lupa *mount* partisi) tidak lagi menutup aplikasi, melainkan menahan proses dan meminta *user* menekan ENTER setelah diperbaiki.
*   **UI:** Menambahkan *Verbose Progress Tracker* untuk menginformasikan direktori spesifik (USER, OBB, MEDIA) yang sedang diproses.

## [v0.2.4] - Bulletproof String Parsing
*   **FIXED:** Masalah PowerShell *ParserError* (`Missing terminator`) akibat metode *copy-paste* karakter kutip. Struktur parameter `Invoke-Expression` dan pemanggilan proses dibongkar menjadi `Start-Process` untuk stabilitas.

## [v0.2.2] - Anti-DRM Play Store
*   **FEATURE:** Menambahkan injeksi argumen `-i com.android.vending` pada Phase 1 OS. Hal ini memanipulasi Android agar menganggap APK diinstal dari Play Store, melakukan *bypass* terhadap sistem lisensi (LVL) *game* berat.

## [v0.2] - Batch & Auto-Sync Edition
*   **FEATURE:** Eksekusi ganda (Batch Support). Pengguna sekarang dapat memasukkan banyak indeks (misal: `1, 3, 5`) sekaligus.
*   **FEATURE:** Auto-Sync Queue System. Phase 1 kini menuliskan *file txt* sementara agar Phase 2 di Recovery dapat membaca antrean tanpa perlu *input* ulang secara manual.