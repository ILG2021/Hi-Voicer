$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "hash-utils.ps1")

$runtimeTag = "v1.13.2"
$runtimeName = "sherpa-onnx-v1.13.2-win-x64-static-MT-Release-no-tts"
$archiveName = "$runtimeName.tar.bz2"
$archiveSha256 = "15D10EC7AF9A8DDCE310BABC293307AEFDD25204A78A0F15684ECEBFA72DF132"
$url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/$runtimeTag/$archiveName"
$repoRoot = Split-Path -Parent $PSScriptRoot
$targetBin = Join-Path $repoRoot "src-tauri\resources\engines\sherpa\$runtimeTag\$runtimeName\bin"
$requiredFiles = @("sherpa-onnx-offline.exe")

$archivePath = Join-Path $env:TEMP $archiveName
$extractDir = Join-Path $env:TEMP "hi-voicer-sherpa-$runtimeTag"
$versionMarker = Join-Path $targetBin ".archive-sha256"
$runtimeReady = (Test-Path -LiteralPath (Join-Path $targetBin "sherpa-onnx-offline.exe")) -and
  (Test-Path -LiteralPath $versionMarker) -and
  ((Get-Content -Raw -LiteralPath $versionMarker).Trim() -eq $archiveSha256)
if ($runtimeReady) {
  Write-Host "Sherpa-ONNX $runtimeTag runtime is already prepared."
  return
}

Save-VerifiedDownload -Url $url -Destination $archivePath -Sha256 $archiveSha256

if (Test-Path -LiteralPath $extractDir) {
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
& tar.exe -xjf $archivePath -C $extractDir
if ($LASTEXITCODE -ne 0) {
  throw "Failed to extract the Sherpa-ONNX CPU archive."
}

$sourceBin = Join-Path $extractDir "$runtimeName\bin"
if (Test-Path -LiteralPath $targetBin) {
  Remove-Item -LiteralPath $targetBin -Recurse -Force
}
New-Item -ItemType Directory -Path $targetBin -Force | Out-Null
foreach ($file in $requiredFiles) {
  $source = Join-Path $sourceBin $file
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Required Sherpa-ONNX executable was not found: $file"
  }
  Copy-Item -LiteralPath $source -Destination (Join-Path $targetBin $file) -Force
}
[IO.File]::WriteAllText($versionMarker, $archiveSha256, (New-Object Text.UTF8Encoding($false)))

$totalBytes = (Get-ChildItem -LiteralPath $targetBin -File | Measure-Object Length -Sum).Sum
Write-Host "Prepared minimal Sherpa-ONNX CPU runtime: $([math]::Round($totalBytes / 1MB, 1)) MiB"

