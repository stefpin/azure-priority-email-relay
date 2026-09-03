$ErrorActionPreference = 'Continue'
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
$fqdn = 'vm-exch.mail.example.com'

Write-Output "=== services ==="
$svc = @(Get-Service MSExchange* -ErrorAction SilentlyContinue)
Write-Output ("SERVICE_COUNT=" + $svc.Count)
Write-Output ("TRANSPORT=" + (Get-Service MSExchangeTransport -ErrorAction SilentlyContinue).Status)

Write-Output "=== connector FQDNs before ==="
Get-ReceiveConnector | ForEach-Object { Write-Output ("  RECV " + $_.Name + " fqdn=" + $_.Fqdn) }
Get-SendConnector    | ForEach-Object { Write-Output ("  SEND " + $_.Name + " fqdn=" + $_.Fqdn) }

# Exchange uses the connector Fqdn for the SMTP HELO/EHLO it presents. Pin both to the
# new name so nothing still announces the old lab suffix.
Get-ReceiveConnector | ForEach-Object { Set-ReceiveConnector -Identity $_.Identity -Fqdn $fqdn }
Get-SendConnector    | ForEach-Object { Set-SendConnector    -Identity $_.Identity -Fqdn $fqdn }

Write-Output "=== connector FQDNs after ==="
Get-ReceiveConnector | ForEach-Object { Write-Output ("  RECV " + $_.Name + " fqdn=" + $_.Fqdn + " remote=" + ($_.RemoteIPRanges -join ',')) }
Get-SendConnector    | ForEach-Object { Write-Output ("  SEND " + $_.Name + " fqdn=" + $_.Fqdn + " smarthost=" + ($_.SmartHosts -join ',') + " port=" + $_.Port + " auth=" + $_.SmartHostAuthMechanism) }

Write-Output "=== queues ==="
Get-Queue | ForEach-Object { Write-Output ("  " + $_.Identity + " count=" + $_.MessageCount + " status=" + $_.Status) }
Write-Output ("EDITION=" + (Get-ExchangeServer).Edition + " ROLE=" + (Get-ExchangeServer).ServerRole)
Write-Output "DONE_FQDN"
