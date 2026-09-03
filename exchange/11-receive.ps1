Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
$rc = Get-ReceiveConnector | Where-Object { $_.Name -like 'Default internal receive connector*' }

# Restrict to the application subnet ONLY. Without this the next command makes an open relay.
Set-ReceiveConnector -Identity $rc.Identity -RemoteIPRanges 10.30.3.0/24
Write-Output ("REMOTE_IP_RANGES=" + ((Get-ReceiveConnector $rc.Identity).RemoteIPRanges -join ','))

# Allow relay to external recipients from that restricted range
Get-ReceiveConnector $rc.Identity |
  Add-ADPermission -User 'NT AUTHORITY\ANONYMOUS LOGON' -ExtendedRights ms-Exch-SMTP-Accept-Any-Recipient -ErrorAction SilentlyContinue | Out-Null

$perm = Get-ReceiveConnector $rc.Identity | Get-ADPermission |
        Where-Object { $_.ExtendedRights -like '*Accept-Any-Recipient*' }
Write-Output ("RELAY_PERM_GRANTED=" + [bool]$perm)
Write-Output ("BINDINGS=" + ((Get-ReceiveConnector $rc.Identity).Bindings -join ','))
Write-Output "DONE_RECEIVE"