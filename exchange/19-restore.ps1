Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
# Keep the connector FQDN consistent with the machine FQDN. The mismatched name gave no
# visible benefit - the Message-ID and Received-SPF both come from the machine FQDN.
Get-ReceiveConnector | ForEach-Object { Set-ReceiveConnector -Identity $_.Identity -Fqdn 'vm-exch.mailrelay.local' }
Get-SendConnector    | ForEach-Object { Set-SendConnector    -Identity $_.Identity -Fqdn $null }
Write-Output ("MACHINE_FQDN=" + [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName)
Get-ReceiveConnector | ForEach-Object { Write-Output ("RECV " + $_.Name + " fqdn=" + $_.Fqdn + " remote=" + ($_.RemoteIPRanges -join ',')) }
Get-SendConnector    | ForEach-Object { Write-Output ("SEND " + $_.Name + " fqdn=" + $_.Fqdn + " smarthost=" + ($_.SmartHosts -join ',') + " port=" + $_.Port) }
Write-Output ("TRANSPORT=" + (Get-Service MSExchangeTransport).Status)
Get-Queue | ForEach-Object { Write-Output ("QUEUE " + $_.Identity + " count=" + $_.MessageCount + " status=" + $_.Status) }
$ev = Get-MessageTrackingLog -Server vm-exch -Start (Get-Date).AddHours(-1) -ResultSize 6
$ev | ForEach-Object { Write-Output ("TRACK " + $_.EventId + " " + $_.Timestamp + " " + $_.Sender) }