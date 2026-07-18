$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "check-runtime-offline.ps1")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& (Join-Path $PSScriptRoot "check-bundled-resources.ps1")
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& npm.cmd run build
exit $LASTEXITCODE
