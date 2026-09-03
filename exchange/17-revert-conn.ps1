Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
# Put the receive connector Fqdn back to what Setup created, to test whether my change broke it
Get-ReceiveConnector | ForEach-Object { Set-ReceiveConnector -Identity $_.Identity -Fqdn 'vm-exch.mailrelay.local' }
Get-ReceiveConnector | ForEach-Object { Write-Output ("RECV " + $_.Name + " fqdn=" + $_.Fqdn) }
Start-Service MSExchangeTransport -ErrorAction SilentlyContinue
Start-Sleep -Seconds 25
Write-Output ("TRANSPORT=" + (Get-Service MSExchangeTransport).Status)
Write-Output ("PORT_25=" + [bool](Get-NetTCPConnection -LocalPort 25 -State Listen -ErrorAction SilentlyContinue))