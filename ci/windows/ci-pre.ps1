# PowerShell equivalent of the `.pre` bash template in .gitlab-ci.yml, run inside the
# Windows CI toolchain container (see ci/windows/Dockerfile). Unlike bash, PowerShell
# does not stop the script when a native executable (flutter/dart/melos) exits non-zero,
# so each call is followed by an explicit $LASTEXITCODE check.
$ErrorActionPreference = "Stop"

flutter upgrade --force
if ($LASTEXITCODE -ne 0) { throw "flutter upgrade failed with exit code $LASTEXITCODE" }
flutter --version
flutter doctor

dart pub global activate melos
if ($LASTEXITCODE -ne 0) { throw "dart pub global activate melos failed with exit code $LASTEXITCODE" }
dart pub global activate junitreport
if ($LASTEXITCODE -ne 0) { throw "dart pub global activate junitreport failed with exit code $LASTEXITCODE" }

Push-Location tools/ci
dart pub get
if ($LASTEXITCODE -ne 0) { throw "dart pub get (tools/ci) failed with exit code $LASTEXITCODE" }
Pop-Location

# `dart pub global activate` installs executables here
$env:PATH = "$env:PATH;C:\Users\ContainerAdministrator\AppData\Local\Pub\Cache\bin"

melos bootstrap
if ($LASTEXITCODE -ne 0) { throw "melos bootstrap failed with exit code $LASTEXITCODE" }

New-Item -ItemType Directory -Force -Path ".\.build\test-results" | Out-Null

melos full_clean
if ($LASTEXITCODE -ne 0) { throw "melos full_clean failed with exit code $LASTEXITCODE" }

melos prepare
if ($LASTEXITCODE -ne 0) { throw "melos prepare failed with exit code $LASTEXITCODE" }
