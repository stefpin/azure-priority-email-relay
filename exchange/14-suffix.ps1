$ErrorActionPreference = 'Continue'
$new = 'mail.example.com'

$k = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
Write-Output ("OLD_SUFFIX=" + (Get-ItemProperty -Path $k -Name 'NV Domain' -ErrorAction SilentlyContinue).'NV Domain')

Set-ItemProperty -Path $k -Name 'NV Domain' -Value $new
Set-ItemProperty -Path $k -Name 'Domain'    -Value $new

# Exchange reads the FQDN from here for HELO and Message-ID, so it must agree.
Write-Output ("NEW_SUFFIX=" + (Get-ItemProperty -Path $k -Name 'NV Domain').'NV Domain')
Write-Output ("CURRENT_FQDN_BEFORE_REBOOT=" + [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName)
Write-Output "REBOOT_REQUIRED"
