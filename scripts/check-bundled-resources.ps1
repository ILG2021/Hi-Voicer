$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "hash-utils.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$resourceRoot = Join-Path $repoRoot "src-tauri\resources"
$cudaLlama = "engines\llama\b9964-cuda\llama-server.exe"
$isCudaBundle = Test-Path -LiteralPath (Join-Path $resourceRoot $cudaLlama)
$requiredFiles = @(
  "engines\ffmpeg\bin\ffmpeg.exe",
  "engines\ffmpeg\bin\ffprobe.exe",
  "engines\sherpa\v1.13.2\sherpa-onnx-v1.13.2-win-x64-static-MT-Release-no-tts\bin\sherpa-onnx-offline.exe",
  "engines\llama\b9964\llama-server.exe",
  "engines\llama\b9964\llama-server-impl.dll",
  "engines\llama\b9964\llama-common.dll",
  "engines\llama\b9964\llama.dll",
  "models\sensevoice-small\engine.json",
  "models\sensevoice-small\model.int8.onnx",
  "models\sensevoice-small\tokens.txt",
  "models\silero_vad.onnx",
  "models\qwen3-asr-0.6b\engine.json",
  "models\qwen3-asr-0.6b\Qwen3-ASR-0.6B-Q8_0.gguf",
  "models\qwen3-asr-0.6b\mmproj-Qwen3-ASR-0.6B-Q8_0.gguf"
)

foreach ($relativePath in $requiredFiles) {
  $path = Join-Path $resourceRoot $relativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required bundled runtime file is missing: $relativePath"
  }
}
if ($isCudaBundle) {
  $cudaDir = Split-Path -Parent (Join-Path $resourceRoot $cudaLlama)
  $cudaBackend = Get-ChildItem -LiteralPath $cudaDir -Filter "*cuda*.dll" -File
  $cudaRuntime = Get-ChildItem -LiteralPath $cudaDir -Filter "*cudart*.dll" -File
  if (-not $cudaBackend -or -not $cudaRuntime) {
    throw "CUDA bundle is missing its CUDA backend or CUDA runtime DLLs."
  }
}

$tokensPath = Join-Path $resourceRoot "models\sensevoice-small\tokens.txt"
$tokensBytes = (Get-Item -LiteralPath $tokensPath).Length
if ($tokensBytes -lt 300KB -or $tokensBytes -gt 330KB) {
  throw "SenseVoice tokens file has an unexpected size: $tokensBytes bytes."
}

$senseConfig = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot "models\sensevoice-small\engine.json") | ConvertFrom-Json
$qwenConfig = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot "models\qwen3-asr-0.6b\engine.json") | ConvertFrom-Json
if ($senseConfig.engine -ne "sherpa-onnx" -or $senseConfig.modelId -ne "sensevoice-small") {
  throw "SenseVoice engine.json does not match the bundled offline engine."
}
if ($qwenConfig.engine -ne "llama-server" -or $qwenConfig.modelId -ne "qwen3-asr-0.6b") {
  throw "Qwen engine.json does not match the bundled offline engine."
}

$verifiedFiles = @{
  "models\sensevoice-small\model.int8.onnx" = "C71F0CE00BEC95B07744E116345E33D8CBBE08CEF896382CF907BF4B51A2CD51"
  "models\silero_vad.onnx" = "9E2449E1087496D8D4CABA907F23E0BD3F78D91FA552479BB9C23AC09CBB1FD6"
  "models\qwen3-asr-0.6b\Qwen3-ASR-0.6B-Q8_0.gguf" = "BCA259818B50CA7C4C05E9BDB35A5DC04FA039653A6D6F3F0F331F96F6AA1971"
  "models\qwen3-asr-0.6b\mmproj-Qwen3-ASR-0.6B-Q8_0.gguf" = "41A342B5E4C514E968CB756DE6CD1B7BE39EFF43C44C57A2EF5FC6522E36603D"
}
foreach ($entry in $verifiedFiles.GetEnumerator()) {
  $path = Join-Path $resourceRoot $entry.Key
  $actualHash = Get-FileSha256 -Path $path
  if ($actualHash -ne $entry.Value) {
    throw "Bundled resource checksum mismatch: $($entry.Key). Expected $($entry.Value), got $actualHash."
  }
}

if (-not $isCudaBundle) {
  $forbidden = Get-ChildItem -Path $resourceRoot -Recurse -File | Where-Object {
    $_.Name -match "cuda|cudnn|tensorrt|vulkan"
  }
  if ($forbidden) {
    $paths = $forbidden.FullName | ForEach-Object { $_.Substring($resourceRoot.Length + 1) }
    throw "GPU runtime files must not enter the CPU installer: $($paths -join ', ')"
  }
}

$totalBytes = (Get-ChildItem -Path $resourceRoot -Recurse -File | Measure-Object Length -Sum).Sum
$maxBytes = 2GB
if ($totalBytes -gt $maxBytes) {
  throw "Bundled resources are too large: $([math]::Round($totalBytes / 1MB, 1)) MiB (limit: $([math]::Round($maxBytes / 1MB, 1)) MiB)."
}

Write-Host "Bundled resources verified: $([math]::Round($totalBytes / 1MB, 1)) MiB"
