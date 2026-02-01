# WireGuard Configuration Script
# Sends configuration to wireguard-go via named pipe

Write-Host "Connecting to WireGuard named pipe..." -ForegroundColor Yellow

try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'ProtectedPrefix\Administrators\WireGuard\wg0', 'InOut')
    $pipe.Connect(5000)
    Write-Host "Connected to pipe!" -ForegroundColor Green

    $writer = New-Object System.IO.StreamWriter($pipe)

    # WireGuard configuration
    # Private key and public key should be in hex format (not base64)
    $config = @"
set=1
private_key=d096774f42849f3323689b4a8c2582cdb985c606777eff1963d843eee3a2e578
public_key=d9e642f06f468bba67e11ed4809bf50d7329b64f6403e5e2a290d3238e17a117
endpoint=212.80.213.27:13233
persistent_keepalive_interval=25
allowed_ip=0.0.0.0/0
allowed_ip=::/0

"@

    $writer.Write($config)
    $writer.Flush()

    $reader = New-Object System.IO.StreamReader($pipe)
    $response = $reader.ReadToEnd()
    $pipe.Close()

    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-Host "Configuration applied successfully (empty response = success)" -ForegroundColor Green
    } else {
        Write-Host "Response: $response" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: Failed to configure WireGuard: $_" -ForegroundColor Red
    Write-Host "Make sure wireguard-go is running and the wg0 interface exists." -ForegroundColor Yellow
}
