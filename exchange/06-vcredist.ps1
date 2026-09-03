$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$url = 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe'
$exe = 'C:\vcredist_x64.exe'

if (-not (Test-Path $exe)) { (New-Object System.Net.WebClient).DownloadFile($url, $exe) }
Write-Output ("VCREDIST_BYTES=" + (Get-Item $exe).Length)

$p = Start-Process -FilePath $exe -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
Write-Output ("VCREDIST_EXIT=" + $p.ExitCode)   # 0 = installed, 1638 = newer already present, 3010 = reboot

$k = Get-ChildItem 'HKLM:\SOFTWARE\Classes\Installer\Dependencies' -ErrorAction SilentlyContinue |
     Where-Object { $_.PSChildName -match 'VC,redist.x64.*11' }
Write-Output ("VC2012_KEY_PRESENT=" + [bool]$k)
Write-Output "DONE_VCREDIST"