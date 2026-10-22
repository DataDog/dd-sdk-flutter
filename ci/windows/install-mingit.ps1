param (
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Sha256
)

$ErrorActionPreference = 'Stop'

$zipUrl = "https://github.com/git-for-windows/git/releases/download/v$($Version).windows.1/MinGit-$($Version)-64-bit.zip"
$zipPath = Join-Path ([IO.Path]::GetTempPath()) 'mingit.zip'

Write-Host "Downloading MinGit archive from: $zipUrl"
Get-RemoteFile -RemoteFile $zipUrl -LocalFile $zipPath -VerifyHash $Sha256

if(! (test-path "c:\devtools\git")){
    md c:\devtools\git
}
& '7z' x -oc:\devtools\git $zipPath
Remove-Item $zipPath

# set path locally so we can initialize git config
Add-ToPath -NewPath "c:\devtools\git\cmd;c:\devtools\git\usr\bin" -Local -Global
& 'git.exe' config --global user.name "Windows Builder"
& 'git.exe' config --global user.email "noreply@datadoghq.com"

# https://andrewlock.net/fixing-max_path-issues-in-gitlab/
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWord -Force
& git config --system core.longpaths true

Write-Host -ForegroundColor Green "MinGit $Version installed."
