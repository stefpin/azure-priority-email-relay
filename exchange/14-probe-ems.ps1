# Read-only probe: confirms what a novice will actually find on vm-exch.
# Nothing here changes state.

Write-Output "=== 1. Is Exchange installed? ==="
$i = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup' -ErrorAction SilentlyContinue
if ($i -and $i.MsiInstallPath) {
    Write-Output ("INSTALLED=YES  path=" + $i.MsiInstallPath)
} else {
    Write-Output "INSTALLED=NO"
}

Write-Output "=== 2. Is the Exchange Management Shell shortcut present? ==="
$lnk = Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -Filter '*Exchange*.lnk' -ErrorAction SilentlyContinue
if ($lnk) { $lnk | ForEach-Object { Write-Output ("  LNK: " + $_.FullName) } } else { Write-Output "  (no shortcut found)" }

Write-Output "=== 3. Does the RemoteExchange profile script exist? ==="
$rem = Join-Path $i.MsiInstallPath 'bin\RemoteExchange.ps1'
Write-Output ("  RemoteExchange.ps1 present = " + (Test-Path $rem))

Write-Output "=== 4. Does Add-PSSnapin work? ==="
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
$snap = Get-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
Write-Output ("  snapin loaded = " + [bool]$snap)

Write-Output "=== 5. 18.8 item 2 - Get-Queue ==="
try {
    $q = Get-Queue -ErrorAction Stop
    if (-not $q) { Write-Output "  (no queues - this is the healthy result)" }
    $q | ForEach-Object { Write-Output ("  " + $_.Identity + " | count=" + $_.MessageCount + " | status=" + $_.Status) }
} catch { Write-Output ("  ERROR: " + $_.Exception.Message) }

Write-Output "=== 6. 18.8 item 3 - Get-MessageTrackingLog ==="
try {
    $t = Get-MessageTrackingLog -Server vm-exch -Start (Get-Date).AddHours(-24) -ResultSize 6 -ErrorAction Stop
    if (-not $t) { Write-Output "  (no events in the last 24h)" }
    $t | ForEach-Object { Write-Output ("  " + $_.EventId + " | " + $_.Timestamp + " | " + $_.Sender + " -> " + ($_.Recipients -join ',')) }
} catch { Write-Output ("  ERROR: " + $_.Exception.Message) }

Write-Output "=== 7. Is RDP enabled on the guest? ==="
$deny = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
Write-Output ("  fDenyTSConnections = " + $deny + "   (0 means RDP is enabled)")
$fw = Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' }
Write-Output ("  enabled RDP firewall rules = " + ($fw | Measure-Object).Count)

Write-Output "=== 8. Windows / PowerShell version ==="
Write-Output ("  " + (Get-CimInstance Win32_OperatingSystem).Caption)
Write-Output ("  PSVersion = " + $PSVersionTable.PSVersion)
