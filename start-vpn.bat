@echo off
:: WireGuard VPN Startup Script Wrapper
:: This batch file runs the PowerShell script with execution policy bypass
:: Run this as Administrator (right-click -> Run as administrator)

echo Starting WireGuard VPN...
echo.

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click start-vpn.bat and select "Run as administrator"
    pause
    exit /b 1
)

:: Run the PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%~dp0start-vpn.ps1"

:: Keep window open if there was an error
if %errorLevel% neq 0 (
    echo.
    echo Script exited with error code %errorLevel%
    pause
)
