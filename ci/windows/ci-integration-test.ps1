param (
    [Parameter(Mandatory=$true)][string]$DdClientToken,
    [Parameter(Mandatory=$true)][string]$DdApplicationId
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\ci-pre.ps1"

$env:DD_CLIENT_TOKEN = $DdClientToken
$env:DD_APPLICATION_ID = $DdApplicationId

melos run integration_test:windows
if ($LASTEXITCODE -ne 0) { throw "melos run integration_test:windows failed with exit code $LASTEXITCODE" }
