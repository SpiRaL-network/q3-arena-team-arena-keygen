@echo off
setlocal
powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0keygen-script\keygen.ps1"
if errorlevel 1 (
    echo Failed to launch Q3 Arena + Team Arena Keygen.
    pause
)
endlocal
