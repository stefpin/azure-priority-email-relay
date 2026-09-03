$i = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup' -ErrorAction SilentlyContinue
if ($i -and $i.MsiInstallPath) { Write-Output "INSTALLED=YES" } else { Write-Output "INSTALLED=NO" }
$p = Get-Process -Name ExSetup,Setup -ErrorAction SilentlyContinue
Write-Output ("SETUP_RUNNING=" + [bool]$p)
if (Test-Path C:\ExchangeSetupLogs\ExchangeSetup.log) {
    $sz = (Get-Item C:\ExchangeSetupLogs\ExchangeSetup.log).Length
    Write-Output ("LOG_BYTES=" + $sz)
    $t = Get-Content C:\ExchangeSetupLogs\ExchangeSetup.log -Tail 40 |
         Where-Object { $_ -match 'Executing|Finished|Error|Failed|COMPLETED|Beginning' } |
         Select-Object -Last 2
    foreach ($x in $t) { Write-Output ("LOG: " + $x.Trim()) }
} else { Write-Output "LOG_BYTES=0" }