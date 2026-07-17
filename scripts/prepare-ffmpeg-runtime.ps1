$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "hash-utils.ps1")

$ffmpegVersion = "8.1.2"
$archiveName = "ffmpeg-$ffmpegVersion-essentials_build.zip"
$archiveSha256 = "DB580001CAA24AC104C8CB856CD113A87B0A443F7BDF47D8C12B1D740584A2EC"
$url = "https://www.gyan.dev/ffmpeg/builds/packages/$archiveName"
$repoRoot = Split-Path -Parent $PSScriptRoot
$targetDir = Join-Path $repoRoot "src-tauri\resources\engines\ffmpeg\bin"
$archivePath = Join-Path $env:TEMP "hi-voicer-$archiveName"
$extractDir = Join-Path $env:TEMP "hi-voicer-ffmpeg-$ffmpegVersion"
$versionMarker = Join-Path $targetDir ".archive-sha256"

$runtimeReady = (Test-Path -LiteralPath (Join-Path $targetDir "ffmpeg.exe")) -and
  (Test-Path -LiteralPath (Join-Path $targetDir "ffprobe.exe")) -and
  (Test-Path -LiteralPath $versionMarker) -and
  ((Get-Content -Raw -LiteralPath $versionMarker).Trim() -eq $archiveSha256)
if ($runtimeReady) {
  Write-Host "FFmpeg $ffmpegVersion runtime is already prepared."
  return
}

Save-VerifiedDownload -Url $url -Destination $archivePath -Sha256 $archiveSha256

if (Test-Path -LiteralPath $extractDir) {
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}
Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
$ffmpeg = Get-ChildItem -LiteralPath $extractDir -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
if (-not $ffmpeg) {
  throw "ffmpeg.exe was not found in the verified archive."
}
$sourceDir = $ffmpeg.Directory.FullName
if (-not (Test-Path -LiteralPath (Join-Path $sourceDir "ffprobe.exe"))) {
  throw "ffprobe.exe was not found next to ffmpeg.exe."
}

if (Test-Path -LiteralPath $targetDir) {
  Remove-Item -LiteralPath $targetDir -Recurse -Force
}
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceDir "ffmpeg.exe") -Destination (Join-Path $targetDir "ffmpeg.exe") -Force
Copy-Item -LiteralPath (Join-Path $sourceDir "ffprobe.exe") -Destination (Join-Path $targetDir "ffprobe.exe") -Force
[IO.File]::WriteAllText($versionMarker, $archiveSha256, (New-Object Text.UTF8Encoding($false)))
Write-Host "Prepared verified FFmpeg runtime at $targetDir"
