@echo off
:: WireGuard Diagnostic Script Wrapper
:: This batch file runs the PowerShell script with execution policy bypass
:: Run this as Administrator (right-click -> Run as administrator)

echo Running WireGuard diagnostics...
echo.

:: Run the PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%~dp0diagnose-wg.ps1"

echo.
pause
