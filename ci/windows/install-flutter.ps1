param (
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Sha256,
    [Parameter(Mandatory=$false)][string]$InstallRoot="c:\devtools\flutter"
)

$ErrorActionPreference = 'Stop'

$zipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$($Version)-stable.zip"
$zipPath = Join-Path ([IO.Path]::GetTempPath()) 'flutter.zip'

Write-Host "Downloading Flutter SDK from: $zipUrl"
Get-RemoteFile -RemoteFile $zipUrl -LocalFile $zipPath -VerifyHash $Sha256

$parent = Split-Path $InstallRoot -Parent
if (! (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent | Out-Null
}
& '7z' x -o"$parent" $zipPath
Remove-Item $zipPath

Add-ToPath -NewPath "$InstallRoot\bin" -Local -Global
Add-ToPath -NewPath "$InstallRoot\bin\cache\dart-sdk\bin" -Local -Global

# CI runs `flutter upgrade --force` on top of this baked-in checkout, so this pinned
# version is just a starting point to avoid re-downloading the whole SDK every build.
& flutter config --enable-windows-desktop
& flutter precache --windows

Reload-Path
Write-Host -ForegroundColor Green "Flutter $Version installed."
