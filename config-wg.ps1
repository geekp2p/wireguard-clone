# WireGuard Configuration Script
# This script configures the wg0 interface via named pipe
# Must be run AFTER wireguard-go.exe has started and created the interface

$pipeName = 'ProtectedPrefix\Administrators\WireGuard\wg0'
$pipeTimeout = 5000

Write-Host "Configuring WireGuard interface..." -ForegroundColor Cyan

# Check if wireguard-go is running
$wgProcess = Get-Process -Name "wireguard-go" -ErrorAction SilentlyContinue
if (-not $wgProcess) {
    Write-Host ""
    Write-Host "ERROR: wireguard-go.exe is not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start wireguard-go first by running:" -ForegroundColor Yellow
    Write-Host "  .\start-vpn.bat  (recommended)" -ForegroundColor White
    Write-Host "  or" -ForegroundColor Gray
    Write-Host "  .\wireguard-go.exe wg0  (manual)" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "Found wireguard-go.exe (PID: $($wgProcess.Id))" -ForegroundColor Green

# Wait a moment for the pipe to be ready
Start-Sleep -Milliseconds 500

try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, 'InOut')

    Write-Host "Connecting to named pipe..." -ForegroundColor Yellow
    $pipe.Connect($pipeTimeout)

    Write-Host "Connected! Sending configuration..." -ForegroundColor Green

    $writer = New-Object System.IO.StreamWriter($pipe)

    # WireGuard UAPI configuration
    # private_key and public_key are in hex format
    # IMPORTANT: UAPI requires Unix LF line endings, not Windows CRLF
    $config = @"
set=1
private_key=d096774f42849f3323689b4a8c2582cdb985c606777eff1963d843eee3a2e578
public_key=d9e642f06f468bb367e11ed34809bf50d5729b64fda41e57a3a290d323b41721
endpoint=212.80.213.27:13233
persistent_keepalive_interval=25
allowed_ip=0.0.0.0/0
allowed_ip=::/0

"@
    # Convert CRLF to LF - UAPI protocol requires Unix line endings
    $config = $config -replace "`r`n", "`n"

    $writer.Write($config)
    $writer.Flush()

    # Read response line-by-line instead of ReadToEnd() to avoid hanging
    # UAPI responds with "errno=N\n\n" for set operations
    $reader = New-Object System.IO.StreamReader($pipe)
    $response = ""
    $readTimeout = 5000  # 5 second timeout
    $startTime = Get-Date

    # Note: Named pipes don't support ReadTimeout property, so we use manual timeout checking
    try {
        while ($true) {
            # Check timeout
            if (((Get-Date) - $startTime).TotalMilliseconds -gt $readTimeout) {
                Write-Host "Read timeout - assuming configuration was applied" -ForegroundColor Yellow
                break
            }

            $line = $reader.ReadLine()
            if ($null -eq $line) {
                # End of stream
                break
            }

            $response += $line + "`n"

            # Check if we got the errno response (end of UAPI response)
            if ($line -match "^errno=") {
                break
            }
        }
    } catch [System.IO.IOException] {
        # Timeout or pipe closed - this is expected
        Write-Host "Pipe read completed" -ForegroundColor Gray
    } catch {
        Write-Host "Read warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $pipe.Close()

    # Check for errno in response
    if ($response -match "errno=(\d+)") {
        $errno = $matches[1]
        if ($errno -eq "0") {
            Write-Host "Configuration applied successfully!" -ForegroundColor Green
        } else {
            Write-Host "Configuration error (errno=$errno): $response" -ForegroundColor Red
            exit 1
        }
    } elseif ([string]::IsNullOrWhiteSpace($response)) {
        # No response but no error - assume success
        Write-Host "Configuration applied (no response received)" -ForegroundColor Green
    } else {
        Write-Host "Response: $response" -ForegroundColor Yellow
    }

} catch [System.TimeoutException] {
    Write-Host ""
    Write-Host "ERROR: Connection to WireGuard pipe timed out!" -ForegroundColor Red
    Write-Host ""
    Write-Host "The named pipe is not responding. Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. wireguard-go.exe crashed or failed to start properly" -ForegroundColor White
    Write-Host "  2. The wg0 interface was not created" -ForegroundColor White
    Write-Host "  3. Permission issues (must run as Administrator)" -ForegroundColor White
    Write-Host ""
    Write-Host "Check the wireguard-go window for error messages." -ForegroundColor Cyan
    exit 1

} catch [System.IO.IOException] {
    Write-Host ""
    Write-Host "ERROR: Pipe I/O error - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "The pipe may have been closed. Try restarting wireguard-go." -ForegroundColor Yellow
    exit 1

} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
