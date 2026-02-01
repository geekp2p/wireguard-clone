$pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'ProtectedPrefix\Administrators\WireGuard\wg0', 'InOut')
$pipe.Connect(5000)
$writer = New-Object System.IO.StreamWriter($pipe)
$writer.Write("set=1`nprivate_key=YOUR_PRIVATE_KEY_HEX`npublic_key=SERVER_PUBLIC_KEY_HEX`nendpoint=212.80.213.27:13233`npersistent_keepalive_interval=25`nallowed_ip=0.0.0.0/0`nallowed_ip=::/0`n`n")
$writer.Flush()
$reader = New-Object System.IO.StreamReader($pipe)
$response = $reader.ReadToEnd()
$pipe.Close()
Write-Host "Response: $response"
