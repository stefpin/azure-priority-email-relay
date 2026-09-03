# Create the send connector from Exchange to Azure Communication Services.
#
# This is the heart of the design: an on-premises Exchange Server relaying to ACS
# over an ordinary authenticated TLS connector, with no application changes.
#
# Credentials come from the environment. Get them from the ACS resource:
#   Portal -> your Communication Services resource -> Email -> SMTP usernames
# The username has the form <app-id>.<tenant-id>.<resource-id> and is long; the
# password is the associated Entra application client secret, shown once.
#
#   $env:ACS_SMTP_USER     = '<the long username>'
#   $env:ACS_SMTP_PASSWORD = '<the client secret>'
#
# Never hardcode either into this file.

$ErrorActionPreference = 'Continue'
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

$user = $env:ACS_SMTP_USER
$pass = $env:ACS_SMTP_PASSWORD
if (-not $user -or -not $pass) {
    Write-Output "SET ACS_SMTP_USER AND ACS_SMTP_PASSWORD FIRST"
    return
}

$sec  = ConvertTo-SecureString $pass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($user, $sec)

# Replace any previous version so this script can be re-run safely
Get-SendConnector -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'To ACS' } |
    Remove-SendConnector -Confirm:$false -ErrorAction SilentlyContinue

# -AddressSpaces '*'            every recipient; there is one destination from here
# -SmartHosts                   hand off to ACS rather than doing our own MX lookup
# -Port 587                     Azure blocks outbound 25 on most subscription types
# -DNSRoutingEnabled $false     without this the smart host is ignored
# -SmartHostAuthMechanism       basic auth, but ONLY over an encrypted session
# -RequireTLS $true             fail rather than fall back to cleartext
New-SendConnector -Name 'To ACS' `
    -AddressSpaces '*' `
    -SmartHosts 'smtp.azurecomm.net' `
    -Port 587 `
    -DNSRoutingEnabled $false `
    -SmartHostAuthMechanism BasicAuthRequireTLS `
    -AuthenticationCredential $cred `
    -RequireTLS $true `
    -Usage Custom | Out-Null

$sc = Get-SendConnector 'To ACS'
Write-Output ('NAME='       + $sc.Name)
Write-Output ('SMARTHOSTS=' + ($sc.SmartHosts -join ','))
Write-Output ('PORT='       + $sc.Port)
Write-Output ('AUTH='       + $sc.SmartHostAuthMechanism)
Write-Output ('REQTLS='     + $sc.RequireTLS)
Write-Output ('DNSROUTING=' + $sc.DNSRoutingEnabled)
Write-Output ('ENABLED='    + $sc.Enabled)
Write-Output 'DONE_SEND_CONNECTOR'
