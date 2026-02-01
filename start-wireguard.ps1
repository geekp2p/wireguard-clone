# WireGuard Startup Script
cd C:\lenovo-arm-32

Write-Host "Starting wireguard-go..." -ForegroundColor Green
Start-Process -FilePath ".\PsExec64.exe" -ArgumentList "-s -i C:\lenovo-arm-32\wireguard-go\wireguard-go.exe wg0"
Start-Sleep -Seconds 3

Write-Host "Sending config..." -ForegroundColor Green
.\PsExec64.exe -s powershell -ExecutionPolicy Bypass -File "C:\lenovo-arm-32\set-wg-config.ps1"
Start-Sleep -Seconds 2

Write-Host "Setting IP address..." -ForegroundColor Green
New-NetIPAddress -InterfaceAlias "wg0" -IPAddress "172.16.1.252" -PrefixLength 32 -ErrorAction SilentlyContinue

Write-Host "Setting DNS..." -ForegroundColor Green
Set-DnsClientServerAddress -InterfaceAlias "wg0" -ServerAddresses "1.1.1.1"

Write-Host "Adding route..." -ForegroundColor Green
New-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -NextHop "0.0.0.0" -RouteMetric 1 -ErrorAction SilentlyContinue

Write-Host "Done! WireGuard is running." -ForegroundColor Green
Get-NetAdapter | Where-Object {$_.Name -eq "wg0"}
