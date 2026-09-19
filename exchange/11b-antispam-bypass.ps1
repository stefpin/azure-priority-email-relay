# Exempt the sending domain from content filtering.
#
# RUN THIS. It is not optional, and skipping it is the single most likely reason
# a one-time-passcode never arrives.
#
# An Edge Transport server enables all ten anti-spam agents by default, and nothing
# is exempt from them until you say so. A one-time passcode is structurally exactly
# what a content filter is built to catch: a very short message whose entire body is
# a numeric code, from a domain the filter has never seen. It can score SCL 7, which
# is the default reject threshold, and Exchange then refuses it at OnEndOfData with:
#
#   550 5.7.1 Message rejected as spam by Content Filtering.
#
# The failure is silent from the sender's point of view. A typical Python sending
# script prints "submitted" and exits 0 because it never checks the SMTP result --
# the exception only appears on stderr. The message never reaches the relay target.
#
# This script exempts ONE trusted sending domain. Filtering stays enabled for every
# other sender, which is the posture that survives a security review.
#
# Set the domain you send from:
#   $env:SENDER_DOMAIN = 'notify.example.com'

$ErrorActionPreference = 'Continue'
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

$domain = $env:SENDER_DOMAIN
if (-not $domain) {
    Write-Output "SET SENDER_DOMAIN FIRST, e.g. `$env:SENDER_DOMAIN = 'notify.example.com'"
    return
}

Write-Output "=== before ==="
$before = Get-ContentFilterConfig
Write-Output ("  ENABLED="                 + $before.Enabled)
Write-Output ("  SCL_REJECT_ENABLED="      + $before.SCLRejectEnabled)
Write-Output ("  SCL_REJECT_THRESHOLD="    + $before.SCLRejectThreshold)
Write-Output ("  BYPASSED_SENDER_DOMAINS=" + ($before.BypassedSenderDomains -join ','))

# Preserve anything already exempted rather than overwriting it
$existing = @($before.BypassedSenderDomains | ForEach-Object { $_.ToString() })
if ($existing -contains $domain) {
    Write-Output "ALREADY_BYPASSED=$domain"
} else {
    $all = @($existing + $domain | Where-Object { $_ })
    Set-ContentFilterConfig -BypassedSenderDomains $all
}

Write-Output "=== after ==="
$after = Get-ContentFilterConfig
Write-Output ("  ENABLED="                 + $after.Enabled)
Write-Output ("  SCL_REJECT_ENABLED="      + $after.SCLRejectEnabled)
Write-Output ("  SCL_REJECT_THRESHOLD="    + $after.SCLRejectThreshold)
Write-Output ("  BYPASSED_SENDER_DOMAINS=" + ($after.BypassedSenderDomains -join ','))

$ok = @($after.BypassedSenderDomains | ForEach-Object { $_.ToString() }) -contains $domain
Write-Output ("BYPASS_APPLIED=" + $ok)

# Filtering must remain ON. If either of these is False somebody has disabled the
# agent wholesale, which is a much blunter change than this script intends.
Write-Output ("FILTERING_STILL_ENABLED=" + ($after.Enabled -and $after.SCLRejectEnabled))

Write-Output "DONE_ANTISPAM_BYPASS"

# Verify by sending one message and then running 20-agentlog.ps1. A successful
# bypass logs:
#     Action     : AcceptMessage
#     Reason     : SCL
#     ReasonData : not available: content filtering was bypassed.
#
# This setting lives in the Exchange configuration in AD LDS on the OS disk, so it
# survives deallocating and restarting the VM. Apply it once, not before every run.
