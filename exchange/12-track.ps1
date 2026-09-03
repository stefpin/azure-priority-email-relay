Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
Write-Output "=== transport queues ==="
Get-Queue | ForEach-Object { Write-Output ("  " + $_.Identity + " | count=" + $_.MessageCount + " | status=" + $_.Status + " | lasterr=" + $_.LastError) }
Write-Output "=== message tracking: SEND events ==="
$ev = Get-MessageTrackingLog -EventId SEND -Start (Get-Date).AddHours(-1) -ResultSize 10
if (-not $ev) { Write-Output "  (no SEND events yet)" }
$ev | ForEach-Object { Write-Output ("  " + $_.Timestamp + " | " + $_.Sender + " -> " + ($_.Recipients -join ',') + " | " + $_.MessageSubject) }
Write-Output "=== any failures ==="
$f = Get-MessageTrackingLog -EventId FAIL -Start (Get-Date).AddHours(-1) -ResultSize 5
if (-not $f) { Write-Output "  (none)" }
$f | ForEach-Object { Write-Output ("  FAIL " + $_.Timestamp + " | " + $_.RecipientStatus) }