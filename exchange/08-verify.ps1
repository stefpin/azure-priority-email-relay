Write-Output "=== Exchange services ==="
Get-Service MSExchange* -ErrorAction SilentlyContinue |
  Select-Object -First 8 | ForEach-Object { Write-Output ("  " + $_.Name + " = " + $_.Status) }
$svc = @(Get-Service MSExchange* -ErrorAction SilentlyContinue)
Write-Output ("SERVICE_COUNT=" + $svc.Count)

Write-Output "=== install path / version ==="
$i = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup' -ErrorAction SilentlyContinue
if ($i) { Write-Output ("MsiInstallPath=" + $i.MsiInstallPath); Write-Output ("Version=" + $i.MsiProductMajor + "." + $i.MsiProductMinor + "." + $i.MsiBuildMajor + "." + $i.MsiBuildMinor) }

Write-Output "=== EdgeTransport role key ==="
$e = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\EdgeTransportRole' -ErrorAction SilentlyContinue
Write-Output ("EDGE_ROLE_KEY=" + [bool]$e)

Write-Output "=== last critical error in setup log ==="
$c = Get-Content 'C:\ExchangeSetupLogs\ExchangeSetup.log'
$c | Where-Object { $_ -match '\[ERROR\]' } | Select-Object -Last 4 | ForEach-Object { Write-Output ("  " + $_.Trim()) }
$c | Select-Object -Last 3 | ForEach-Object { Write-Output ("  TAIL " + $_.Trim()) }