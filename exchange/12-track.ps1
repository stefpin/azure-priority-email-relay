# Queues and message tracking. Read-only.
#
# Two things about message tracking on an Edge Transport server catch people out,
# and both are corrected here:
#
#   1. Get-MessageTrackingLog returns NOTHING unless you pass -Server <name>.
#      There is no useful default on Edge.
#
#   2. The outbound event is SENDEXTERNAL, not SEND. Filtering on SEND finds
#      nothing even when delivery succeeded perfectly.
#
# A healthy relayed message produces RECEIVE followed by SENDEXTERNAL, a few
# seconds apart. A lone FAIL with no RECEIVE means an agent rejected it before it
# was ever queued -- run 20-agentlog.ps1 to find out which one and why.

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

$srv = $env:COMPUTERNAME
$hrs = 1
if ($env:TRACK_HOURS) { $hrs = [int]$env:TRACK_HOURS }

Write-Output "=== transport queues ==="
Get-Queue | ForEach-Object {
    Write-Output ("  " + $_.Identity + " | count=" + $_.MessageCount + " | status=" + $_.Status + " | lasterr=" + $_.LastError)
}

Write-Output "=== message tracking: RECEIVE then SENDEXTERNAL ==="
$ev = Get-MessageTrackingLog -Server $srv -Start (Get-Date).AddHours(-$hrs) -ResultSize 20 |
      Where-Object { $_.EventId -eq 'RECEIVE' -or $_.EventId -eq 'SENDEXTERNAL' } |
      Sort-Object Timestamp
if (-not $ev) { Write-Output "  (nothing in the last $hrs hour(s))" }
$ev | ForEach-Object {
    Write-Output ("  " + $_.Timestamp.ToString('HH:mm:ss') + " | " + $_.EventId.ToString().PadRight(12) +
                  " | " + $_.Sender + " -> " + ($_.Recipients -join ',') + " | " + $_.MessageSubject)
}

Write-Output "=== any failures ==="
$f = Get-MessageTrackingLog -Server $srv -EventId FAIL -Start (Get-Date).AddHours(-$hrs) -ResultSize 10
if (-not $f) { Write-Output "  (none)" }
$f | ForEach-Object {
    Write-Output ("  FAIL " + $_.Timestamp.ToString('HH:mm:ss') + " | " + $_.MessageSubject)
    Write-Output ("        " + ($_.RecipientStatus -join ' '))
    Write-Output ("        -> a FAIL with no matching RECEIVE usually means an anti-spam agent")
    Write-Output ("           rejected it. Run 20-agentlog.ps1.")
}
Write-Output "DONE_TRACK"