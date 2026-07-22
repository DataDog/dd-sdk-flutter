param (
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Url,
    [Parameter(Mandatory=$true)][string]$Sha256,
    [Parameter(Mandatory=$false)][string]$InstallRoot="c:\devtools\vstudio"
)

$ErrorActionPreference = 'Stop'

# This is a subset of the components dd-sdk-cpp installs: just enough for CMake +
# MSVC to build the dd-sdk-cpp FFI shim and for `flutter build windows` to build the
# Flutter Windows runner (Desktop C++ workload, x64 tools, ATL, Windows 11 SDK).
$VSPackages = @(
    "Microsoft.VisualStudio.Component.VC.ATL",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre",
    "Microsoft.VisualStudio.Workload.NativeDesktop",
    "Microsoft.VisualStudio.Workload.VCTools",
    "Microsoft.VisualStudio.Component.Windows11SDK.26100"
)

$filename = Split-Path $Url -Leaf
$exePath = Join-Path ([IO.Path]::GetTempPath()) 'vs_buildtools.exe'

Write-Host "Downloading Visual Studio installer from: $Url"
Get-RemoteFile -RemoteFile $Url -LocalFile $exePath -VerifyHash $Sha256

Write-Host "File size is $((get-item $exePath).length)"
$VSPackageListParam = $VSPackages -join " --add "
$ArgList = "--quiet --wait --norestart --nocache --installPath `"$($InstallRoot)`" --add $VSPackageListParam"
$processparams = @{
    FilePath = $exePath
    NoNewWindow = $true
    Wait = $true
    ArgumentList = $ArgList
    PassThru = $true
}
$st = get-date
Write-Host "Installing Visual Studio $Version..."
$process = Start-Process @processparams
Write-Host "Installer finished."

# Check exit code
if ($process.ExitCode -ne 0) {
    throw "Visual Studio installation failed with exit code: $($process.ExitCode)"
}

# Verify installation by checking for MSBuild
$msbuildPath = Join-Path $InstallRoot "MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuildPath)) {
    throw "Visual Studio installation verification failed: MSBuild not found at expected location: $msbuildPath"
}
Write-Host -ForegroundColor Green "Visual Studio installation verified: MSBuild found at $msbuildPath"

Add-EnvironmentVariable -Variable VSTUDIO_ROOT -Value $InstallRoot -Global -Local
Add-ToPath -NewPath "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64" -Global

Remove-Item $exePath
Reload-Path
Write-Host -ForegroundColor Green "$filename $Version installed."
