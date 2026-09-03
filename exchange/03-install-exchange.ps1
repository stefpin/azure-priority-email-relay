# Launch Exchange Edge Transport setup.
#
# CRITICAL: setup MUST run as a real user account, not as SYSTEM.
#
# Edge Transport creates an AD LDS instance during setup, and AD LDS requires a
# valid user account as its administrator. If setup runs as SYSTEM - which is what
# `az vm run-command` does - it fails with:
#
#   "AD LDS install error: The value entered for Administrator is not a valid
#    user account."
#
# So this script drives setup through a scheduled task running as azureuser.
# The alternative is to RDP in over Bastion and run Setup.exe interactively.
#
# Supply the password in EXCH_ADMIN_PASSWORD. Never hardcode it into this file.

$ErrorActionPreference = 'Continue'
$iso  = 'C:\ExchangeServerSE-x64.iso'
$pw   = $env:EXCH_ADMIN_PASSWORD
$user = 'azureuser'

if (-not $pw) { Write-Output "SET EXCH_ADMIN_PASSWORD FIRST"; return }

# --- mount the ISO (idempotent) ---------------------------------------------
$di = Get-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue
if (-not $di -or -not $di.Attached) { $di = Mount-DiskImage -ImagePath $iso -PassThru }
$drive = ($di | Get-Volume).DriveLetter
Write-Output ("MOUNTED=" + $drive)

$setup = "${drive}:\Setup.exe"
if (-not (Test-Path $setup)) { Write-Output "SETUP_NOT_FOUND"; return }

# --- already installed? ------------------------------------------------------
$inst = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup' -ErrorAction SilentlyContinue
if ($inst -and $inst.MsiInstallPath) {
    Write-Output ("ALREADY_INSTALLED=" + $inst.MsiInstallPath)
    return
}

# --- launch as a real user ---------------------------------------------------
# No product key is supplied, so this installs as Trial Edition. Confirm after
# with: (Get-ExchangeServer).Edition  ->  StandardEvaluation
$exArgs = '/Mode:Install /Role:EdgeTransport /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF'

schtasks /delete /TN ExchSetup /F 2>$null | Out-Null
schtasks /create /TN ExchSetup /TR "$setup $exArgs" /SC ONCE /ST 23:59 `
         /RU $user /RP $pw /RL HIGHEST /F | Out-Null
schtasks /run /TN ExchSetup | Out-Null

Start-Sleep -Seconds 15
Write-Output ('TASK=' + ((schtasks /query /TN ExchSetup /FO LIST | Select-String 'Status') -join ' '))
Write-Output "SETUP_LAUNCHED_AS_USER"
Write-Output "Setup takes roughly 40 minutes. Poll with 04-status.ps1."