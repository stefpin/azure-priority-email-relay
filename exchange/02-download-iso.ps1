$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$iso = 'C:\ExchangeServerSE-x64.iso'
$url = 'https://download.microsoft.com/download/ad9b1e53-f28e-4a82-987d-6c88803795b2/ExchangeServerSE-x64.iso'

if ((Test-Path $iso) -and (Get-Item $iso).Length -ge 6402453504) {
    Write-Output ("ALREADY_PRESENT bytes=" + (Get-Item $iso).Length)
} else {
    Remove-Item $iso -ErrorAction SilentlyContinue
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    (New-Object System.Net.WebClient).DownloadFile($url, $iso)
    $sw.Stop()
    Write-Output ("DOWNLOADED bytes=" + (Get-Item $iso).Length + " seconds=" + [int]$sw.Elapsed.TotalSeconds)
}
Write-Output "DONE_DOWNLOAD"