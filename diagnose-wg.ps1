# WireGuard Connection Diagnostic Script
# Run as Administrator

$vpnEndpoint = "212.80.213.27"
$vpnPort = 13233

Write-Host "=== WireGuard Connection Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check if wg0 interface exists
Write-Host "[1] Checking wg0 interface..." -ForegroundColor Yellow
$adapter = Get-NetAdapter -Name "wg0" -ErrorAction SilentlyContinue
if ($adapter) {
    Write-Host "    wg0 Status: $($adapter.Status)" -ForegroundColor $(if ($adapter.Status -eq 'Up') {'Green'} else {'Red'})
} else {
    Write-Host "    wg0 interface NOT FOUND" -ForegroundColor Red
}

# 2. Check routing
Write-Host ""
Write-Host "[2] Checking routing to VPN endpoint..." -ForegroundColor Yellow
$endpointRoute = Get-NetRoute -DestinationPrefix "$vpnEndpoint/32" -ErrorAction SilentlyContinue
if ($endpointRoute) {
    $ifMetric = (Get-NetIPInterface -InterfaceIndex $endpointRoute.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
    $effectiveMetric = $endpointRoute.RouteMetric + $ifMetric
    Write-Host "    Endpoint route: $vpnEndpoint -> $($endpointRoute.NextHop) via $($endpointRoute.InterfaceAlias)" -ForegroundColor Green
    Write-Host "    Route metric: $($endpointRoute.RouteMetric), Interface metric: $ifMetric, Effective: $effectiveMetric" -ForegroundColor Gray
} else {
    Write-Host "    WARNING: No specific route for VPN endpoint!" -ForegroundColor Red
    Write-Host "    Handshake packets may be routing through wg0 (infinite loop)" -ForegroundColor Red
}

$defaultRoutes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric
Write-Host "    Default routes (sorted by route metric):"
foreach ($route in $defaultRoutes) {
    $color = if ($route.InterfaceAlias -eq "wg0") {'Cyan'} else {'White'}
    $ifMetric = (Get-NetIPInterface -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
    $effectiveMetric = $route.RouteMetric + $ifMetric
    Write-Host "      $($route.InterfaceAlias) -> $($route.NextHop) (route: $($route.RouteMetric), if: $ifMetric, effective: $effectiveMetric)" -ForegroundColor $color
}

# Check if wg0 would intercept endpoint traffic
$wg0Route = $defaultRoutes | Where-Object { $_.InterfaceAlias -eq "wg0" }
if ($wg0Route -and $endpointRoute) {
    $wg0IfMetric = (Get-NetIPInterface -InterfaceIndex $wg0Route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
    $wg0Effective = $wg0Route.RouteMetric + $wg0IfMetric
    $endpointIfMetric = (Get-NetIPInterface -InterfaceIndex $endpointRoute.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
    $endpointEffective = $endpointRoute.RouteMetric + $endpointIfMetric
    Write-Host ""
    Write-Host "    Routing analysis:" -ForegroundColor Yellow
    Write-Host "      Endpoint route (/32) has effective metric $endpointEffective" -ForegroundColor Gray
    Write-Host "      wg0 default route (/0) has effective metric $wg0Effective" -ForegroundColor Gray
    Write-Host "      /32 always takes precedence over /0 (more specific wins)" -ForegroundColor Green
}

# 3. Test UDP connectivity
Write-Host ""
Write-Host "[3] Testing UDP connectivity to $vpnEndpoint`:$vpnPort..." -ForegroundColor Yellow
try {
    $udpClient = New-Object System.Net.Sockets.UdpClient
    $udpClient.Client.ReceiveTimeout = 3000
    $udpClient.Connect($vpnEndpoint, $vpnPort)

    # Send a small packet (won't be a valid WireGuard packet, but tests connectivity)
    $testData = [byte[]](1,0,0,0)
    $sent = $udpClient.Send($testData, $testData.Length)
    Write-Host "    UDP packet sent ($sent bytes)" -ForegroundColor Green

    # Try to receive (will likely timeout since server won't respond to invalid packet)
    try {
        $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $received = $udpClient.Receive([ref]$remoteEP)
        Write-Host "    Received response from $($remoteEP.Address):$($remoteEP.Port)" -ForegroundColor Green
    } catch {
        Write-Host "    No response (expected - test packet was not valid WireGuard)" -ForegroundColor Yellow
    }
    $udpClient.Close()
} catch {
    Write-Host "    UDP connection FAILED: $_" -ForegroundColor Red
}

# 4. Check Windows Firewall
Write-Host ""
Write-Host "[4] Checking Windows Firewall..." -ForegroundColor Yellow
$fwProfiles = Get-NetFirewallProfile
foreach ($profile in $fwProfiles) {
    $status = if ($profile.Enabled) {'ENABLED'} else {'Disabled'}
    $color = if ($profile.Enabled) {'Yellow'} else {'Green'}
    Write-Host "    $($profile.Name): $status" -ForegroundColor $color
}

# Check for WireGuard rules
$wgRules = Get-NetFirewallRule -DisplayName "*wireguard*" -ErrorAction SilentlyContinue
if ($wgRules) {
    Write-Host "    WireGuard firewall rules found:" -ForegroundColor Green
    foreach ($rule in $wgRules) {
        Write-Host "      $($rule.DisplayName): $($rule.Enabled)" -ForegroundColor White
    }
} else {
    Write-Host "    No WireGuard-specific firewall rules found" -ForegroundColor Yellow
}

# 5. Check named pipe
Write-Host ""
Write-Host "[5] Checking WireGuard named pipe..." -ForegroundColor Yellow
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'ProtectedPrefix\Administrators\WireGuard\wg0', 'InOut')
    $pipe.Connect(2000)

    $writer = New-Object System.IO.StreamWriter($pipe)
    $writer.Write("get=1`n`n")
    $writer.Flush()

    $reader = New-Object System.IO.StreamReader($pipe)
    $response = $reader.ReadToEnd()
    $pipe.Close()

    Write-Host "    Pipe connection: OK" -ForegroundColor Green
    Write-Host ""
    Write-Host "[6] Current WireGuard status:" -ForegroundColor Yellow

    # Parse response
    $lines = $response -split "`n"
    foreach ($line in $lines) {
        if ($line -match "^public_key=(.+)") {
            $pubKey = $matches[1]
            # Convert hex to base64 for display
            $bytes = for ($i = 0; $i -lt $pubKey.Length; $i += 2) { [Convert]::ToByte($pubKey.Substring($i, 2), 16) }
            $base64Key = [Convert]::ToBase64String($bytes)
            Write-Host "    Peer public key: $($base64Key.Substring(0,8))..." -ForegroundColor White
        }
        if ($line -match "^endpoint=(.+)") {
            Write-Host "    Endpoint: $($matches[1])" -ForegroundColor White
        }
        if ($line -match "^last_handshake_time_sec=(.+)") {
            $timestamp = [int64]$matches[1]
            if ($timestamp -gt 0) {
                $dt = (Get-Date "1970-01-01").AddSeconds($timestamp)
                Write-Host "    Last handshake: $dt" -ForegroundColor Green
            } else {
                Write-Host "    Last handshake: NEVER" -ForegroundColor Red
            }
        }
        if ($line -match "^tx_bytes=(.+)") {
            Write-Host "    TX bytes: $($matches[1])" -ForegroundColor White
        }
        if ($line -match "^rx_bytes=(.+)") {
            Write-Host "    RX bytes: $($matches[1])" -ForegroundColor White
        }
    }
} catch {
    Write-Host "    Pipe connection FAILED: $_" -ForegroundColor Red
    Write-Host "    Is wireguard-go running?" -ForegroundColor Yellow
}

# 7. Calculate and display client public key
Write-Host ""
Write-Host "[7] Client public key (for server configuration):" -ForegroundColor Yellow
$privateKeyHex = "d096774f42849f3323689b4a8c2582cdb985c606777eff1963d843eee3a2e578"
Write-Host "    To configure on server, add this peer's public key" -ForegroundColor Cyan
Write-Host "    (Run 'wg show' on this machine to see the public key)" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If handshake is failing (client sends but server doesn't respond):" -ForegroundColor White
Write-Host ""
Write-Host "  MOST COMMON: Client public key not configured on server" -ForegroundColor Yellow
Write-Host "    Run .\show-client-pubkey.ps1 to get the public key" -ForegroundColor Cyan
Write-Host "    Add it to server config with: AllowedIPs = 172.16.1.252/32" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Other checks:" -ForegroundColor White
Write-Host "  1. Is the WireGuard server running at $vpnEndpoint`:$vpnPort?" -ForegroundColor White
Write-Host "  2. Does server's public key in config-wg.ps1 match 'wg show' on server?" -ForegroundColor White
Write-Host "  3. Are the allowed IPs on the server configured for 172.16.1.252?" -ForegroundColor White
Write-Host "  4. Is UDP port $vpnPort open on server firewall?" -ForegroundColor White
Write-Host "  5. Is Windows Firewall blocking outbound UDP?" -ForegroundColor White
Write-Host ""
Write-Host "To verify server config, run on server:" -ForegroundColor Yellow
Write-Host "  wg show" -ForegroundColor White
Write-Host ""
