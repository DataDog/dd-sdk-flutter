param (
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Sha256
)

$ErrorActionPreference = 'Stop'

$shortenedver = $Version.Replace('.','')
$exeUrl="https://www.7-zip.org/a/7z$($shortenedver)-x64.exe"
$exePath = Join-Path ([IO.Path]::GetTempPath()) '7zip.exe'

Write-Host "Downloading 7-Zip installer from: $exeUrl"
Get-RemoteFile -RemoteFile $exeUrl -LocalFile $exePath -VerifyHash $Sha256

Start-Process $exePath -ArgumentList '/S' -Wait
Add-ToPath -NewPath "c:\program files\7-zip" -Local -Global

Remove-Item $exePath
Reload-Path
Write-Host -ForegroundColor Green "7-Zip $Version installed."
