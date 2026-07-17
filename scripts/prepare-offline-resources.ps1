$ErrorActionPreference = "Stop"

$scripts = @(
  "check-runtime-offline.ps1",
  "prepare-ffmpeg-runtime.ps1",
  "prepare-sherpa-runtime.ps1",
  "prepare-llama-runtime.ps1",
  "prepare-offline-models.ps1",
  "check-bundled-resources.ps1"
)

foreach ($script in $scripts) {
  & (Join-Path $PSScriptRoot $script)
  if ($LASTEXITCODE -ne 0) {
    throw "$script failed with exit code $LASTEXITCODE"
  }
}

Write-Host "All offline package resources are ready." -ForegroundColor Green
