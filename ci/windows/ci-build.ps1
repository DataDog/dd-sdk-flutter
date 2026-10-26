$ErrorActionPreference = "Stop"

. "$PSScriptRoot\ci-pre.ps1"

melos run build:windows
if ($LASTEXITCODE -ne 0) { throw "melos run build:windows failed with exit code $LASTEXITCODE" }

melos run unit_test:windows
if ($LASTEXITCODE -ne 0) { throw "melos run unit_test:windows failed with exit code $LASTEXITCODE" }
