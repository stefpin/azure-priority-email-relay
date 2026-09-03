$f = 'C:\ExchangeSetupLogs\ExchangeSetup.log'
$c = Get-Content $f
Write-Output ("TOTAL_LINES=" + $c.Count)
Write-Output "=== errors / prerequisite failures ==="
$c | Where-Object { $_ -match 'ERROR|FAIL|not satisfied|prerequisite|Recommended|cannot be|required' } |
     Select-Object -Last 25 | ForEach-Object { Write-Output $_.Trim() }
Write-Output "=== last 10 lines ==="
$c | Select-Object -Last 10 | ForEach-Object { Write-Output $_.Trim() }