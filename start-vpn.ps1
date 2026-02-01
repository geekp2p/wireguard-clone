cd C:\wireguard-go

$vpnEndpoint = "212.80.213.27"

Write-Host "=== Step 1: Finding Wi-Fi gateway ===" -ForegroundColor Cyan
$wifiRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -ne "wg0" } |
    Sort-Object -Property RouteMetric |
    Select-Object -First 1

$wifiGateway = $wifiRoute.NextHop
$wifiInterface = $wifiRoute.InterfaceAlias
Write-Host "Found: $wifiGateway via $wifiInterface" -ForegroundColor Green

Write-Host "=== Step 2: Adding route for VPN endpoint ===" -ForegroundColor Cyan
Remove-NetRoute -DestinationPrefix "$vpnEndpoint/32" -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -DestinationPrefix "$vpnEndpoint/32" -NextHop $wifiGateway -InterfaceAlias $wifiInterface -RouteMetric 1

Write-Host "=== Step 3: Starting wireguard-go ===" -ForegroundColor Cyan
Start-Process -FilePath ".\PsExec64.exe" -ArgumentList "-s -i .\wireguard-go.exe wg0"
Start-Sleep -Seconds 4

Write-Host "=== Step 4: Configure WireGuard ===" -ForegroundColor Cyan
.\PsExec64.exe -s powershell -ExecutionPolicy Bypass -File "C:\wireguard-go\config-wg.ps1"
Start-Sleep -Seconds 2

Write-Host "=== Step 5: Setting IP ===" -ForegroundColor Cyan
Remove-NetIPAddress -InterfaceAlias "wg0" -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceAlias "wg0" -IPAddress "172.16.1.252" -PrefixLength 32

Write-Host "=== Step 6: Setting DNS ===" -ForegroundColor Cyan
Set-DnsClientServerAddress -InterfaceAlias "wg0" -ServerAddresses "1.1.1.1"

Write-Host "=== Step 7: Adding default route ===" -ForegroundColor Cyan
New-NetRoute -InterfaceAlias "wg0" -DestinationPrefix "0.0.0.0/0" -NextHop "0.0.0.0" -RouteMetric 5

Write-Host "Done! Check for 'Keypair created' message." -ForegroundColor Green
