$ErrorActionPreference = 'Continue'
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

$s = Get-Service MSExchangeTransport
Write-Output ("BEFORE status=" + $s.Status + " startType=" + $s.StartType)

if ($s.Status -ne 'Running') {
    Start-Service MSExchangeTransport -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 20
}
$s = Get-Service MSExchangeTransport
Write-Output ("AFTER  status=" + $s.Status + " startType=" + $s.StartType)

if ($s.Status -ne 'Running') {
    Write-Output "=== last transport errors in the event log ==="
    Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2} -MaxEvents 6 -ErrorAction SilentlyContinue |
      ForEach-Object { Write-Output ("  " + $_.TimeCreated + " [" + $_.ProviderName + "] " + ($_.Message -split "`n")[0]) }
}

Write-Output "=== listening on 25 ==="
$l = Get-NetTCPConnection -LocalPort 25 -State Listen -ErrorAction SilentlyContinue
Write-Output ("PORT_25_LISTENING=" + [bool]$l)

Write-Output "=== queues ==="
Get-Queue -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ("  " + $_.Identity + " count=" + $_.MessageCount + " status=" + $_.Status) }
Write-Output "DONE_TRANSPORT"
