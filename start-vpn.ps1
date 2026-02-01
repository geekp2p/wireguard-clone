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

Write-Host "=== Step 7: Waiting for handshake ===" -ForegroundColor Cyan
Write-Host "IMPORTANT: The server must have this client's public key configured!" -ForegroundColor Yellow

# Client public key (pre-computed from private key)
$clientPublicKey = "RVilpi9wTgHMpAHr+w1DUv9WiaCRAdVdAUNq4rKY2mk="
Write-Host ""
Write-Host "Client Public Key: $clientPublicKey" -ForegroundColor Green
Write-Host ""
Write-Host "Add to server with:" -ForegroundColor Yellow
Write-Host "  wg set wg0 peer $clientPublicKey allowed-ips 172.16.1.252/32" -ForegroundColor White
Write-Host ""

# Wait for handshake to complete before adding default route
$handshakeTimeout = 30
$handshakeSuccess = $false
$startTime = Get-Date

Write-Host "Waiting up to $handshakeTimeout seconds for handshake..." -ForegroundColor Yellow

while (((Get-Date) - $startTime).TotalSeconds -lt $handshakeTimeout) {
    try {
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'ProtectedPrefix\Administrators\WireGuard\wg0', 'InOut')
        $pipe.Connect(2000)
        $writer = New-Object System.IO.StreamWriter($pipe)
        $writer.Write("get=1`n`n")
        $writer.Flush()
        $reader = New-Object System.IO.StreamReader($pipe)
        $response = $reader.ReadToEnd()
        $pipe.Close()

        # Check if last_handshake_time_sec is non-zero (handshake succeeded)
        if ($response -match "last_handshake_time_sec=(\d+)") {
            $timestamp = [int64]$matches[1]
            if ($timestamp -gt 0) {
                Write-Host "Handshake successful!" -ForegroundColor Green
                $handshakeSuccess = $true
                break
            }
        }
    } catch {
        # Pipe connection failed, wireguard-go might not be ready
    }

    Write-Host "  Waiting for handshake... ($([int]((Get-Date) - $startTime).TotalSeconds)s)" -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

if (-not $handshakeSuccess) {
    Write-Host ""
    Write-Host "WARNING: Handshake did not complete within $handshakeTimeout seconds!" -ForegroundColor Red
    Write-Host "NOT adding default route through wg0 (would break internet connectivity)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. Server doesn't have this client's public key configured" -ForegroundColor White
    Write-Host "  2. Server's public key in config-wg.ps1 doesn't match actual server" -ForegroundColor White
    Write-Host "  3. UDP port 13233 is blocked by firewall" -ForegroundColor White
    Write-Host "  4. Server is not running or unreachable" -ForegroundColor White
    Write-Host ""
    Write-Host "Run .\show-client-pubkey.ps1 and verify server configuration" -ForegroundColor Cyan
    Write-Host "The VPN interface is UP but traffic is NOT routed through it" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Step 8: Adding default route ===" -ForegroundColor Cyan
Remove-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -NextHop "0.0.0.0" -RouteMetric 5 -ErrorAction SilentlyContinue
Write-Host "Default route added through wg0" -ForegroundColor Green

Write-Host ""
Write-Host "=== Status ===" -ForegroundColor Cyan
Get-NetAdapter -Name "wg0" -ErrorAction SilentlyContinue | Format-Table Name, Status, LinkSpeed
Get-NetIPAddress -InterfaceAlias "wg0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Format-Table IPAddress, PrefixLength

Write-Host ""
Write-Host "VPN is connected and all traffic is now routed through the tunnel!" -ForegroundColor Green
