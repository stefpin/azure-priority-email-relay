$k = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
Set-ItemProperty -Path $k -Name 'NV Domain' -Value 'mailrelay.local'
Set-ItemProperty -Path $k -Name 'Domain'    -Value 'mailrelay.local'
Write-Output ("SUFFIX_RESTORED=" + (Get-ItemProperty -Path $k -Name 'NV Domain').'NV Domain')
Write-Output "REBOOT_REQUIRED"