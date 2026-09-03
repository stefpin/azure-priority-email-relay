$f = 'C:\ExchangeSetupLogs\ExchangeSetup.log'
$c = Get-Content $f
$idx = ($c | Select-String -Pattern 'critical error' | Select-Object -Last 1).LineNumber
Write-Output ("CRITICAL_AT_LINE=" + $idx)
$start = [Math]::Max(0, $idx - 40)
$c[$start..($idx+2)] | Where-Object { $_ -match 'ERROR|Exception|failed|Failed' } |
  Select-Object -Last 14 | ForEach-Object { Write-Output $_.Trim() }