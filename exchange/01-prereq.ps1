$ErrorActionPreference = 'Continue'

Write-Output "=== egress test ==="
$t = Test-NetConnection smtp.azurecomm.net -Port 587 -WarningAction SilentlyContinue
Write-Output ("ACS_587_REACHABLE=" + $t.TcpTestSucceeded)

Write-Output "=== AD LDS ==="
$r = Install-WindowsFeature ADLDS
Write-Output ("ADLDS_SUCCESS=" + $r.Success + " RESTART_NEEDED=" + $r.RestartNeeded)

Write-Output "=== primary DNS suffix ==="
$k = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
Set-ItemProperty -Path $k -Name 'NV Domain' -Value 'mailrelay.local'
Set-ItemProperty -Path $k -Name 'Domain'    -Value 'mailrelay.local'
Write-Output ("SUFFIX=" + (Get-ItemProperty -Path $k -Name 'NV Domain').'NV Domain')

Write-Output "=== paging file: Exchange wants min=max=25% of RAM ==="
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
$pf = [int]($ramGB * 1024 * 0.25)
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.AutomaticManagedPagefile) {
    Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile = $false} | Out-Null
}
$p = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
if ($p) {
    Set-CimInstance -InputObject $p -Property @{InitialSize = $pf; MaximumSize = $pf} | Out-Null
} else {
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{Name = 'C:\pagefile.sys'; InitialSize = $pf; MaximumSize = $pf} | Out-Null
}
Write-Output ("PAGEFILE_MB=" + $pf)

Write-Output "=== capacity ==="
Write-Output ("RAM_GB="    + $ramGB)
Write-Output ("C_FREE_GB=" + [math]::Round((Get-PSDrive C).Free / 1GB, 1))
Write-Output ("OS="        + (Get-CimInstance Win32_OperatingSystem).Caption)
Write-Output "DONE_PREREQ"
