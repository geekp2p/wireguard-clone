# WireGuard Configuration Script (Alternative)
# Sends configuration to wireguard-go via named pipe

Write-Host "Connecting to WireGuard named pipe..." -ForegroundColor Yellow

try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'ProtectedPrefix\Administrators\WireGuard\wg0', 'InOut')
    $pipe.Connect(5000)
    Write-Host "Connected to pipe!" -ForegroundColor Green

    $writer = New-Object System.IO.StreamWriter($pipe)

    # WireGuard configuration (compact format)
    $config = "set=1`nprivate_key=d096774f42849f3323689b4a8c2582cdb985c606777eff1963d843eee3a2e578`npublic_key=d9e642f06f468bb367e11ed34809bf50d5729b64fda41e57a3a290d323b41721`nendpoint=212.80.213.27:13233`npersistent_keepalive_interval=25`nallowed_ip=0.0.0.0/0`nallowed_ip=::/0`n`n"

    $writer.Write($config)
    $writer.Flush()

    $reader = New-Object System.IO.StreamReader($pipe)
    $response = $reader.ReadToEnd()
    $pipe.Close()

    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-Host "Configuration applied successfully!" -ForegroundColor Green
    } else {
        Write-Host "Response: $response" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: Failed to configure WireGuard: $_" -ForegroundColor Red
    Write-Host "Make sure wireguard-go is running and the wg0 interface exists." -ForegroundColor Yellow
}
