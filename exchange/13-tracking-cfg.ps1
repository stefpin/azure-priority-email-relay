Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
$ts = Get-TransportService
Write-Output ("MessageTrackingLogEnabled=" + $ts.MessageTrackingLogEnabled)
Write-Output ("MessageTrackingLogPath="    + $ts.MessageTrackingLogPath)
Write-Output ("SubjectLoggingEnabled="     + $ts.MessageTrackingLogSubjectLoggingEnabled)
Write-Output "=== files on disk ==="
$path = $ts.MessageTrackingLogPath
if ($path -and (Test-Path $path)) {
  Get-ChildItem $path | Select-Object -Last 3 | ForEach-Object { Write-Output ("  " + $_.Name + " " + $_.Length + " bytes") }
} else { Write-Output "  (path missing or empty)" }
Write-Output "=== try with -Server ==="
$e = Get-MessageTrackingLog -Server vm-exch -Start (Get-Date).AddHours(-2) -ResultSize 5 -ErrorAction SilentlyContinue
if ($e) { $e | ForEach-Object { Write-Output ("  " + $_.EventId + " " + $_.Timestamp + " " + $_.Sender + " -> " + ($_.Recipients -join ',')) } }
else { Write-Output "  (still none)" }
Write-Output "=== SMTP send protocol log setting ==="
$sc = Get-SendConnector 'To ACS OTP'
Write-Output ("ProtocolLoggingLevel=" + $sc.ProtocolLoggingLevel)
Write-Output ("SendProtocolLogPath=" + $ts.SendProtocolLogPath)