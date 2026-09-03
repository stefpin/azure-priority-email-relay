# Clear the setup failure watermark so Exchange setup can be retried.
#
# If an Exchange setup attempt fails part way through, it leaves a watermark in the
# registry. Every subsequent attempt then aborts within about seven seconds with:
#
#   "[REQUIRED] A Setup failure previously occurred while installing the
#    EdgeTransportRole role. Either run Setup again for just this role, or remove
#    the role using Control Panel."
#
# That message is misleading - re-running setup does NOT clear it by itself. You
# have to remove the watermark values first.
#
# Run this, then re-run 03-install-exchange.ps1. If the files were already unpacked
# by the failed attempt, the retry completes in about four minutes rather than forty.

$ErrorActionPreference = 'Continue'
$k = 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\EdgeTransportRole'

if (-not (Test-Path $k)) { Write-Output "NO_EDGE_ROLE_KEY - nothing to clear"; return }

foreach ($v in 'Watermark', 'Action', 'UnpackedVersion') {
    if (Get-ItemProperty -Path $k -Name $v -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $k -Name $v -Force -ErrorAction SilentlyContinue
        Write-Output ("CLEARED=" + $v)
    }
}

Write-Output ("REMAINING=" + ((Get-Item $k).Property -join ','))
Write-Output "Now re-run 03-install-exchange.ps1"
