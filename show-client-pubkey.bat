@echo off
:: Show Client Public Key Script Wrapper
:: This batch file runs the PowerShell script with execution policy bypass

echo Getting WireGuard client public key...
echo.

:: Run the PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%~dp0show-client-pubkey.ps1"

echo.
pause
