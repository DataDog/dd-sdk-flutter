$ErrorActionPreference = 'Stop'

. .\helpers.ps1

try {
    .\install-7zip.ps1 -Version "25.01" -Sha256 "78afa2a1c773caf3cf7edf62f857d2a8a5da55fb0fff5da416074c0d28b2b55f"
    .\install-mingit.ps1 -Version "2.26.2" -Sha256 "2dfbb1c46547c70179442a92b8593d592292b8bce2fd02ac4e0051a8072dde8f"
    .\install-cmake.ps1 -Version "3.30.2" -Sha256 "31f799a9e7756305f74cd821970a793e599ead230925392886f45aed897a3c0e"
    .\install-vstudio.ps1 -Version "17.14" -Url "https://download.visualstudio.microsoft.com/download/pr/e98d75fa-91b1-47a1-9cb7-b6556de592c5/b4fab6d6d479c38a6081ec95e32d7a105d21d19b6ae7f97371f716dbea08303d/vs_BuildTools.exe" -Sha256 "B4FAB6D6D479C38A6081EC95E32D7A105D21D19B6AE7F97371F716DBEA08303D"
    .\install-flutter.ps1 -Version "3.44.7" -Sha256 "327b89c2ff612418c1d756efc9636d7811c50e4b50a916d07bc3bdc317ba25e5"
} catch {
    Write-Host -ForegroundColor Red "Error installing build dependencies"
    Write-Host -ForegroundColor Red $($_.ScriptStackTrace)
    exit -1
} finally {
    Remove-Item -Recurse -Force c:\tmp\* -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Env:TEMP\* -ErrorAction SilentlyContinue
}
