@echo off
title MADNDK SYSTEM DEPLOYMENT TOOLKIT v1.0 (Ultimate Edition)
color 0B

:MENU
cls
echo ===============================================================================
echo      __  __            _ _   _  ____   _  __
echo     ^|  \/  ^| __ _   __^| ^| \ ^| ^| ^|  _ \ ^| ^|/ /
echo     ^| ^|\/^| ^|/ _` ^| / _` ^|  \^| ^| ^| ^| ^| ^|^| ' / 
echo     ^| ^|  ^| ^| (_^| ^| ^| (_^| ^| ^|\  ^| ^| ^|_^| ^|^| . \ 
echo     ^|_^|  ^|_^|\__,_^| \__,_^|_^| \_^| ^|____/ ^|_^|\_\
echo.
echo                   SYSTEM DEPLOYMENT TOOLKIT v1.0
echo                         (Ultimate Edition)
echo ===============================================================================
echo.
echo  [ PILIH PROTOKOL EKSEKUSI ]
echo.
echo  [1] INITIATE SYSTEM BACKUP (BATCH)
echo      Target : Recovery Mode (OrangeFox) ^| Status: Data Mounted
echo.
echo  [2] INITIATE RESTORE PHASE 1 : PACKAGE DEPLOYMENT
echo      Target : OS Utama (Homescreen)     ^| Status: USB Debugging Aktif
echo.
echo  [3] INITIATE RESTORE PHASE 2 : DATA RECOVERY ^& SYNC
echo      Target : Recovery Mode (OrangeFox) ^| Status: Data Mounted
echo.
echo  [4] MADNDK MANUAL PUSHER (DIRECT INJECTION) - [ NEW! ]
echo      Target : Universal (OS / Recovery) ^| Status: ADB Connected
echo.
echo  [0] TERMINATE SESSION (CLOSE TOOLKIT)
echo ===============================================================================
echo.
set /p pil="[MADNDK-CLI] Masukkan indeks protokol (0-4): "

if "%pil%"=="1" goto BACKUP
if "%pil%"=="2" goto RESTORE1
if "%pil%"=="3" goto RESTORE2
if "%pil%"=="4" goto PUSHER
if "%pil%"=="0" exit
goto MENU

:BACKUP
cls
if not exist "%~dp0MadNDKBackup.ps1" ( echo [!] Modul tidak ditemukan! & pause & goto MENU )
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "%~dp0MadNDKBackup.ps1"
goto MENU

:RESTORE1
cls
if not exist "%~dp0MadNDKRestorePhase1_OS.ps1" ( echo [!] Modul tidak ditemukan! & pause & goto MENU )
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "%~dp0MadNDKRestorePhase1_OS.ps1"
goto MENU

:RESTORE2
cls
if not exist "%~dp0MadNDKRestorePhase2_Recovery.ps1" ( echo [!] Modul tidak ditemukan! & pause & goto MENU )
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "%~dp0MadNDKRestorePhase2_Recovery.ps1"
goto MENU

:PUSHER
cls
if not exist "%~dp0MadNDK_ManualPusher.ps1" ( echo [!] Modul tidak ditemukan! & pause & goto MENU )
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File "%~dp0MadNDK_ManualPusher.ps1"
goto MENU