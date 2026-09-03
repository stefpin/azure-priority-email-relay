$ErrorActionPreference = 'Continue'
$iso = 'C:\ExchangeServerSE-x64.iso'

# Mount (idempotent - if already mounted just find the drive)
$di = Get-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue
if (-not $di -or -not $di.Attached) { $di = Mount-DiskImage -ImagePath $iso -PassThru }
$drive = ($di | Get-Volume).DriveLetter
Write-Output ("MOUNTED=" + $drive)

$setup = "${drive}:\Setup.exe"
if (-not (Test-Path $setup)) { Write-Output "SETUP_NOT_FOUND"; return }
Write-Output ("SETUP_FOUND=" + $setup)

# Already installed?
$inst = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup' -ErrorAction SilentlyContinue
if ($inst -and $inst.MsiInstallPath) { Write-Output ("ALREADY_INSTALLED=" + $inst.MsiInstallPath); return }

# Launch setup detached so run-command does not have to wait ~40 minutes.
# No product key is supplied, so this installs as Trial Edition.
$args = '/Mode:Install /Role:EdgeTransport /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF'
Start-Process -FilePath $setup -ArgumentList $args -WindowStyle Hidden
Write-Output "SETUP_LAUNCHED"