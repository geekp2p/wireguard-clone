# WireGuard Startup Script
cd C:\lenovo-arm-32

# VPN Server Endpoint - MUST route through Wi-Fi, not wg0
$vpnEndpoint = "212.80.213.27"

Write-Host "=== Step 1: Finding Wi-Fi gateway ===" -ForegroundColor Cyan
# Find the current default gateway (Wi-Fi)
$wifiRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Wireless*" -or $_.InterfaceAlias -like "*WLAN*" } |
    Select-Object -First 1

if (-not $wifiRoute) {
    # Fallback: get any default route that's not wg0
    $wifiRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -ne "wg0" } |
        Sort-Object -Property RouteMetric |
        Select-Object -First 1
}

if ($wifiRoute) {
    $wifiGateway = $wifiRoute.NextHop
    $wifiInterface = $wifiRoute.InterfaceAlias
    Write-Host "Found gateway: $wifiGateway via $wifiInterface" -ForegroundColor Green
} else {
    Write-Host "ERROR: Cannot find Wi-Fi gateway!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Step 2: Adding route for VPN endpoint ===" -ForegroundColor Cyan
# CRITICAL: Add route for VPN server BEFORE starting wireguard
# This ensures handshake packets go through Wi-Fi, not wg0
Remove-NetRoute -DestinationPrefix "$vpnEndpoint/32" -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -DestinationPrefix "$vpnEndpoint/32" -NextHop $wifiGateway -InterfaceAlias $wifiInterface -RouteMetric 1 -ErrorAction SilentlyContinue
Write-Host "Route added: $vpnEndpoint -> $wifiGateway via $wifiInterface" -ForegroundColor Green

Write-Host ""
Write-Host "=== Step 3: Starting wireguard-go ===" -ForegroundColor Cyan
Start-Process -FilePath ".\PsExec64.exe" -ArgumentList "-s -i C:\lenovo-arm-32\wireguard-go\wireguard-go.exe wg0"
Write-Host "Waiting for interface to be created..."
Start-Sleep -Seconds 4

# Wait for wg0 to appear
$retries = 0
while ($retries -lt 10) {
    $adapter = Get-NetAdapter -Name "wg0" -ErrorAction SilentlyContinue
    if ($adapter) {
        Write-Host "Interface wg0 is ready!" -ForegroundColor Green
        break
    }
    Write-Host "Waiting for wg0... ($retries)"
    Start-Sleep -Seconds 1
    $retries++
}

if (-not $adapter) {
    Write-Host "ERROR: wg0 interface not created!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Step 4: Sending WireGuard config ===" -ForegroundColor Cyan
.\PsExec64.exe -s powershell -ExecutionPolicy Bypass -File "C:\lenovo-arm-32\set-wg-config.ps1"
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "=== Step 5: Setting IP address ===" -ForegroundColor Cyan
Remove-NetIPAddress -InterfaceAlias "wg0" -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceAlias "wg0" -IPAddress "172.16.1.252" -PrefixLength 32 -ErrorAction SilentlyContinue
Write-Host "IP set: 172.16.1.252/32" -ForegroundColor Green

Write-Host ""
Write-Host "=== Step 6: Setting DNS ===" -ForegroundColor Cyan
Set-DnsClientServerAddress -InterfaceAlias "wg0" -ServerAddresses "1.1.1.1"
Write-Host "DNS set: 1.1.1.1" -ForegroundColor Green

Write-Host ""
Write-Host "=== Step 7: Adding default route through wg0 ===" -ForegroundColor Cyan
Remove-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -NextHop "0.0.0.0" -RouteMetric 5 -ErrorAction SilentlyContinue
Write-Host "Default route added through wg0" -ForegroundColor Green

Write-Host ""
Write-Host "=== Step 8: Waiting for handshake ===" -ForegroundColor Cyan
Write-Host "Please check the wireguard-go window for 'Keypair created' message" -ForegroundColor Yellow
Write-Host "This may take up to 30 seconds..."
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "=== Status ===" -ForegroundColor Cyan
Get-NetAdapter -Name "wg0" | Format-Table Name, Status, LinkSpeed
Get-NetIPAddress -InterfaceAlias "wg0" -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength

Write-Host ""
Write-Host "=== Route Check ===" -ForegroundColor Cyan
Write-Host "VPN Endpoint route:"
Get-NetRoute -DestinationPrefix "$vpnEndpoint/32" | Format-Table DestinationPrefix, NextHop, InterfaceAlias
Write-Host "Default route:"
Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Format-Table DestinationPrefix, NextHop, InterfaceAlias, RouteMetric

Write-Host ""
Write-Host "=== Testing Connection ===" -ForegroundColor Cyan
Write-Host "Testing ping to VPN server..."
$pingResult = Test-Connection -ComputerName $vpnEndpoint -Count 2 -ErrorAction SilentlyContinue
if ($pingResult) {
    Write-Host "VPN server is reachable!" -ForegroundColor Green
} else {
    Write-Host "Note: VPN server may not respond to ICMP ping (this is normal)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! Check wireguard-go window for handshake status." -ForegroundColor Green
Write-Host "If you see 'Keypair created for peer', the VPN is working!" -ForegroundColor Green