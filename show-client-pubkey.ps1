# Script to show the client's public key for server configuration
# The server needs this public key to accept connections from this client

# Client keys (pre-computed)
$privateKeyHex = "d096774f42849f3323689b4a8c2582cdb985c606777eff1963d843eee3a2e578"
$publicKeyHex = "4558a5a62f704e01cca401ebfb0d4352ff5689a09101d55d01436ae2b298da69"
$publicKeyBase64 = "RVilpi9wTgHMpAHr+w1DUv9WiaCRAdVdAUNq4rKY2mk="

# Server's expected public key
$serverPubKeyHex = "d9e642f06f468bb367e11ed34809bf50d5729b64fda41e57a3a290d323b41721"
$serverPubKeyBase64 = "2eZC8G9Gi7Nn4R7TSAm/UNVym2T9pB5Xo6KQ0yO0FyE="

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  CLIENT PUBLIC KEY (add this to server)   " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  $publicKeyBase64" -ForegroundColor Green
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Add this peer configuration to your WireGuard server:" -ForegroundColor Yellow
Write-Host ""
Write-Host "[Peer]" -ForegroundColor White
Write-Host "PublicKey = $publicKeyBase64" -ForegroundColor White
Write-Host "AllowedIPs = 172.16.1.252/32" -ForegroundColor White
Write-Host ""

Write-Host "Or via command line on the server:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  wg set wg0 peer $publicKeyBase64 allowed-ips 172.16.1.252/32" -ForegroundColor White
Write-Host ""

Write-Host "=== Expected Server Configuration ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This client expects the server to have:" -ForegroundColor Yellow
Write-Host "  Public Key: $serverPubKeyBase64" -ForegroundColor White
Write-Host "  Endpoint:   212.80.213.27:13233" -ForegroundColor White
Write-Host ""
Write-Host "Verify with 'wg show' on your server." -ForegroundColor Yellow
Write-Host ""

Write-Host "=== Troubleshooting ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If handshake keeps failing after adding the peer:" -ForegroundColor Yellow
Write-Host "  1. Check server's public key matches: $serverPubKeyBase64" -ForegroundColor White
Write-Host "  2. Ensure UDP port 13233 is open on server firewall" -ForegroundColor White
Write-Host "  3. Run 'wg show' on server to verify peer was added" -ForegroundColor White
Write-Host "  4. Check server logs for any errors" -ForegroundColor White
Write-Host ""
