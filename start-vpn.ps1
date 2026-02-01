# WireGuard VPN Startup Script
# Run this script as Administrator in PowerShell

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Get the script directory (where wireguard-go.exe should be)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = Get-Location }
cd $scriptDir

$vpnEndpoint = "212.80.213.27"

Write-Host "=== Step 1: Finding Wi-Fi gateway ===" -ForegroundColor Cyan
$wifiRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -ne "wg0" } |
    Sort-Object -Property RouteMetric |
    Select-Object -First 1

if (-not $wifiRoute) {
    Write-Host "ERROR: Cannot find default gateway!" -ForegroundColor Red
    exit 1
}

$wifiGateway = $wifiRoute.NextHop
$wifiInterface = $wifiRoute.InterfaceAlias
Write-Host "Found: $wifiGateway via $wifiInterface" -ForegroundColor Green

Write-Host "=== Step 2: Adding route for VPN endpoint ===" -ForegroundColor Cyan
Remove-NetRoute -DestinationPrefix "$vpnEndpoint/32" -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -DestinationPrefix "$vpnEndpoint/32" -NextHop $wifiGateway -InterfaceAlias $wifiInterface -RouteMetric 1 -ErrorAction SilentlyContinue
Write-Host "Route added: $vpnEndpoint -> $wifiGateway" -ForegroundColor Green

Write-Host "=== Step 3: Starting wireguard-go ===" -ForegroundColor Cyan
# Check if wireguard-go.exe exists
$wgExe = Join-Path $scriptDir "wireguard-go.exe"
if (-not (Test-Path $wgExe)) {
    Write-Host "ERROR: wireguard-go.exe not found in $scriptDir" -ForegroundColor Red
    exit 1
}

# Start wireguard-go in a new window (runs as current admin user)
Start-Process -FilePath $wgExe -ArgumentList "wg0" -WindowStyle Normal
Write-Host "Started wireguard-go.exe, waiting for interface..." -ForegroundColor Yellow

# Wait for wg0 interface to appear
$retries = 0
$maxRetries = 15
while ($retries -lt $maxRetries) {
    Start-Sleep -Seconds 1
    $adapter = Get-NetAdapter -Name "wg0" -ErrorAction SilentlyContinue
    if ($adapter) {
        Write-Host "Interface wg0 created!" -ForegroundColor Green
        break
    }
    $retries++
    Write-Host "  Waiting for wg0... ($retries/$maxRetries)"
}

if (-not $adapter) {
    Write-Host "ERROR: wg0 interface was not created!" -ForegroundColor Red
    Write-Host "Check the wireguard-go window for errors." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Step 4: Configure WireGuard ===" -ForegroundColor Cyan
# Run the config script directly
$configScript = Join-Path $scriptDir "config-wg.ps1"
if (Test-Path $configScript) {
    & $configScript
} else {
    Write-Host "WARNING: config-wg.ps1 not found, skipping configuration" -ForegroundColor Yellow
}
Start-Sleep -Seconds 2

Write-Host "=== Step 5: Setting IP ===" -ForegroundColor Cyan
Remove-NetIPAddress -InterfaceAlias "wg0" -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceAlias "wg0" -IPAddress "172.16.1.252" -PrefixLength 32 -ErrorAction SilentlyContinue
Write-Host "IP set: 172.16.1.252/32" -ForegroundColor Green

Write-Host "=== Step 6: Setting DNS ===" -ForegroundColor Cyan
Set-DnsClientServerAddress -InterfaceAlias "wg0" -ServerAddresses "1.1.1.1" -ErrorAction SilentlyContinue
Write-Host "DNS set: 1.1.1.1" -ForegroundColor Green

Write-Host "=== Step 7: Adding default route ===" -ForegroundColor Cyan
Remove-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -NextHop "0.0.0.0" -RouteMetric 5 -ErrorAction SilentlyContinue
Write-Host "Default route added through wg0" -ForegroundColor Green

Write-Host ""
Write-Host "=== Status ===" -ForegroundColor Cyan
Get-NetAdapter -Name "wg0" -ErrorAction SilentlyContinue | Format-Table Name, Status, LinkSpeed
Get-NetIPAddress -InterfaceAlias "wg0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Format-Table IPAddress, PrefixLength

Write-Host ""
Write-Host "Done! Check wireguard-go window for 'Keypair created' message." -ForegroundColor Green
Write-Host "If handshake succeeds, your VPN is working!" -ForegroundColor Green
