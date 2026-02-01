@echo off
:: WireGuard Configuration Script Wrapper
:: This batch file runs the PowerShell script with execution policy bypass
:: Run this as Administrator (right-click -> Run as administrator)

echo Configuring WireGuard...
echo.

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click config-wg.bat and select "Run as administrator"
    pause
    exit /b 1
)

:: Run the PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%~dp0config-wg.ps1"

if %errorLevel% neq 0 (
    echo.
    echo Script exited with error code %errorLevel%
    pause
)
