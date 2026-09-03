$c = Get-Content 'C:\ExchangeSetupLogs\ExchangeSetup.log'
# find the start of the most recent setup run
$starts = ($c | Select-String -Pattern 'Starting Microsoft Exchange Server .* Setup').LineNumber
$last = $starts | Select-Object -Last 1
Write-Output ("LAST_RUN_STARTS_AT_LINE=" + $last + " of " + $c.Count)
$seg = $c[($last-1)..($c.Count-1)]
Write-Output ("SEGMENT_LINES=" + $seg.Count)
Write-Output "=== errors in the most recent run ==="
$seg | Where-Object { $_ -match 'AdamInstall|not a valid user|\[ERROR\]|REQUIRED' } |
  Select-Object -First 12 | ForEach-Object { Write-Output ("  " + $_.Trim()) }
Write-Output "=== AD LDS instance present? ==="
Write-Output ("ADAM_SVC=" + [bool](Get-Service ADAM_MSExchange -ErrorAction SilentlyContinue))
Get-ChildItem 'C:\Program Files\Microsoft\Exchange Server\V15' -ErrorAction SilentlyContinue |
  Select-Object -First 6 | ForEach-Object { Write-Output ("  DIR " + $_.Name) }