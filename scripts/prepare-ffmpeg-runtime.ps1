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

Invoke-WebRequest -Uri $url -OutFile $archivePath
$actualHash = Get-FileSha256 -Path $archivePath
if ($actualHash -ne $archiveSha256) {
  throw "FFmpeg archive checksum mismatch. Expected $archiveSha256, got $actualHash."
}

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
Write-Host "Prepared verified FFmpeg runtime at $targetDir"
