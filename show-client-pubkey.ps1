# Script to show the client's public key for server configuration
# The server needs this public key to accept connections from this client

# Client's private key (from config)
$privateKeyHex = "d096774f42849f3323689b4a8c2582cdb985c606777eff1963d843eee3a2e578"

# Convert hex to bytes
$privateKeyBytes = New-Object byte[] 32
for ($i = 0; $i -lt 32; $i++) {
    $privateKeyBytes[$i] = [Convert]::ToByte($privateKeyHex.Substring($i * 2, 2), 16)
}

# Convert to base64 (for wg format)
$privateKeyBase64 = [Convert]::ToBase64String($privateKeyBytes)

Write-Host "=== Client Key Information ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Private Key (hex):    $privateKeyHex" -ForegroundColor Yellow
Write-Host "Private Key (base64): $privateKeyBase64" -ForegroundColor Yellow
Write-Host ""
Write-Host "To find your PUBLIC key, run this on the server:" -ForegroundColor Green
Write-Host "  echo '$privateKeyBase64' | wg pubkey" -ForegroundColor White
Write-Host ""
Write-Host "Then add the resulting public key to your server's WireGuard config:" -ForegroundColor Green
Write-Host "[Peer]" -ForegroundColor White
Write-Host "PublicKey = <output from above command>" -ForegroundColor White
Write-Host "AllowedIPs = 172.16.1.252/32" -ForegroundColor White
Write-Host ""

# Also show the expected peer public key (server's public key) that's configured
$peerPubKeyHex = "d9e642f06f468bba67e11ed4809bf50d7329b64f6403e5e2a290d3238e17a117"
$peerPubKeyBytes = New-Object byte[] 32
for ($i = 0; $i -lt 32; $i++) {
    $peerPubKeyBytes[$i] = [Convert]::ToByte($peerPubKeyHex.Substring($i * 2, 2), 16)
}
$peerPubKeyBase64 = [Convert]::ToBase64String($peerPubKeyBytes)

Write-Host "=== Server Key (expected) ===" -ForegroundColor Cyan
Write-Host "Your config expects the server to have this public key:" -ForegroundColor Yellow
Write-Host "  $peerPubKeyBase64" -ForegroundColor White
Write-Host ""
Write-Host "Verify this matches 'wg show' on your server!" -ForegroundColor Red
