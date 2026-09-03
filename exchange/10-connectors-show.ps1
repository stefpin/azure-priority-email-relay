Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
Write-Output ("SNAPIN=" + [bool](Get-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue))
Write-Output "=== receive connectors ==="
Get-ReceiveConnector | ForEach-Object {
  Write-Output ("  " + $_.Name + " | bindings=" + ($_.Bindings -join ',') + " | remote=" + ($_.RemoteIPRanges -join ',') + " | perms=" + ($_.PermissionGroups))
}
Write-Output "=== send connectors ==="
$s = @(Get-SendConnector)
if ($s.Count -eq 0) { Write-Output "  (none)" }
$s | ForEach-Object { Write-Output ("  " + $_.Name + " | " + ($_.AddressSpaces -join ',') + " | smarthost=" + ($_.SmartHosts -join ',')) }
Write-Output ("EDITION=" + (Get-ExchangeServer).Edition)
Write-Output ("SERVERROLE=" + (Get-ExchangeServer).ServerRole)