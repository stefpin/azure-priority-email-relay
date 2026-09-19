# Read the anti-spam agent log. Read-only.
#
# This is the command that names the culprit when a message disappears. It reports
# which agent acted, what it did, and the score it acted on -- none of which is
# visible in the message tracking log, which only shows the resulting FAIL.
#
# Typical use: a message was sent, the sending script reported success, and nothing
# arrived. Run this.

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

$mins = 30
if ($env:AGENTLOG_MINUTES) { $mins = [int]$env:AGENTLOG_MINUTES }

Write-Output "=== content filter configuration ==="
$cfg = Get-ContentFilterConfig
Write-Output ("  ENABLED="                 + $cfg.Enabled)
Write-Output ("  SCL_REJECT_ENABLED="      + $cfg.SCLRejectEnabled)
Write-Output ("  SCL_REJECT_THRESHOLD="    + $cfg.SCLRejectThreshold)
Write-Output ("  BYPASSED_SENDERS="        + ($cfg.BypassedSenders -join ','))
Write-Output ("  BYPASSED_SENDER_DOMAINS=" + ($cfg.BypassedSenderDomains -join ','))
if (-not $cfg.BypassedSenderDomains) {
    Write-Output "  NOTE: no domain is exempt. If a passcode is missing, run 11b-antispam-bypass.ps1."
}

Write-Output ""
Write-Output "=== transport agents ==="
Get-TransportAgent | ForEach-Object {
    Write-Output ("  " + $_.Identity + " | enabled=" + $_.Enabled + " | priority=" + $_.Priority)
}

Write-Output ""
Write-Output "=== agent log, last $mins minutes ==="
$log = Get-AgentLog -StartDate (Get-Date).AddMinutes(-$mins) -EndDate (Get-Date)
if (-not $log) {
    Write-Output "  (empty -- no agent acted on any message in this window)"
    Write-Output "  On a healthy relay this log stays empty. Entries here mean an agent"
    Write-Output "  intervened, so anything at all is worth reading."
}
$log | ForEach-Object {
    Write-Output ("  " + $_.Timestamp)
    Write-Output ("     AGENT=  " + $_.Agent)
    Write-Output ("     EVENT=  " + $_.Event)
    Write-Output ("     ACTION= " + $_.Action)
    Write-Output ("     SMTP=   " + $_.SmtpResponse)
    Write-Output ("     REASON= " + $_.Reason + " / " + $_.ReasonData)
    Write-Output ("     FROM=   " + $_.P1FromAddress)
    Write-Output ("     TO=     " + ($_.Recipients -join ','))
}

Write-Output ""
Write-Output "=== how to read this ==="
Write-Output "  Action=RejectMessage, Reason=SclAtOrAboveRejectThreshold"
Write-Output "     The content filter refused it. Run 11b-antispam-bypass.ps1."
Write-Output "  Action=AcceptMessage, ReasonData='not available: content filtering was bypassed.'"
Write-Output "     The bypass is working. This is the line you want to see."
Write-Output "DONE_AGENTLOG"
