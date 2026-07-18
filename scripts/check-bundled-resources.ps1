$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "hash-utils.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$resourceRoot = Join-Path $repoRoot "src-tauri\resources"

# ── Determine variant: prefer explicit env var, fall back to auto-detect ──
$buildVariant = $env:HIVOICER_BUILD_VARIANT
if (-not $buildVariant) {
  $cudaAutoDetect = Test-Path -LiteralPath (Join-Path $resourceRoot "engines\llama\b9964-cuda\llama-server.exe")
  $buildVariant   = if ($cudaAutoDetect) { "cuda" } else { "cpu" }
  Write-Host "HIVOICER_BUILD_VARIANT not set — auto-detected variant: $buildVariant" -ForegroundColor DarkYellow
}
$isCudaBundle = $buildVariant -eq "cuda"

# ── Variant-specific llama required files ──
$llamaRequiredFiles = if ($isCudaBundle) {
  @(
    "engines\llama\b9964-cuda\llama-server.exe",
    "engines\llama\b9964-cuda\llama-server-impl.dll",
    "engines\llama\b9964-cuda\llama-common.dll",
    "engines\llama\b9964-cuda\llama.dll"
  )
} else {
  @(
    "engines\llama\b9964\llama-server.exe",
    "engines\llama\b9964\llama-server-impl.dll",
    "engines\llama\b9964\llama-common.dll",
    "engines\llama\b9964\llama.dll"
  )
}

$requiredFiles = @(
  "engines\ffmpeg\bin\ffmpeg.exe",
  "engines\ffmpeg\bin\ffprobe.exe",
  "engines\sherpa\v1.13.2\sherpa-onnx-v1.13.2-win-x64-static-MT-Release-no-tts\bin\sherpa-onnx-offline.exe",
  "models\sensevoice-small\engine.json",
  "models\sensevoice-small\model.int8.onnx",
  "models\sensevoice-small\tokens.txt",
  "models\sherpa-paraformer-zh\engine.json",
  "models\sherpa-paraformer-zh\model.int8.onnx",
  "models\sherpa-paraformer-zh\tokens.txt",
  "models\sherpa-paraformer-zh\am.mvn",
  "models\silero_vad.onnx",
  "models\qwen3-asr-0.6b\engine.json",
  "models\qwen3-asr-0.6b\Qwen3-ASR-0.6B-Q8_0.gguf",
  "models\qwen3-asr-0.6b\mmproj-Qwen3-ASR-0.6B-Q8_0.gguf"
) + $llamaRequiredFiles

Write-Host "Checking bundled resources for [$buildVariant] variant..." -ForegroundColor Cyan
foreach ($relativePath in $requiredFiles) {
  $path = Join-Path $resourceRoot $relativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required bundled runtime file is missing: $relativePath"
  }
}

if ($isCudaBundle) {
  # Inno Setup handles large files via streaming -- full cudart bundle is supported.
  # Both the GPU backend (ggml-cuda.dll) and CUDA runtime DLLs must be present.
  $cudaDir = Join-Path $resourceRoot "engines\llama\b9964-cuda"
  $cudaBackend = Get-ChildItem -LiteralPath $cudaDir -Filter "ggml-cuda*.dll" -File
  $cudaRuntime = Get-ChildItem -LiteralPath $cudaDir -Filter "*cudart*.dll" -File
  if (-not $cudaBackend) {
    throw "CUDA bundle is missing the ggml-cuda backend DLL in: $cudaDir"
  }
  if (-not $cudaRuntime) {
    throw "CUDA bundle is missing CUDA runtime DLLs (cudart*.dll) in: $cudaDir"
  }
}

$senseConfig = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot "models\sensevoice-small\engine.json") | ConvertFrom-Json
$qwenConfig = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot "models\qwen3-asr-0.6b\engine.json") | ConvertFrom-Json
$paraformerConfig = Get-Content -Raw -LiteralPath (Join-Path $resourceRoot "models\sherpa-paraformer-zh\engine.json") | ConvertFrom-Json
if ($senseConfig.engine -ne "sherpa-onnx" -or $senseConfig.modelId -ne "sensevoice-small") {
  throw "SenseVoice engine.json does not match the bundled offline engine."
}
if ($qwenConfig.engine -ne "llama-server" -or $qwenConfig.modelId -ne "qwen3-asr-0.6b") {
  throw "Qwen engine.json does not match the bundled offline engine."
}
if ($paraformerConfig.engine -ne "sherpa-onnx" -or $paraformerConfig.modelId -ne "sherpa-paraformer-zh") {
  throw "Paraformer engine.json does not match the bundled offline engine."
}

$verifiedFiles = @{
  # Model files are intentionally not checksum-validated so users can bring
  # their own compatible models without prepare/setup replacing them.
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
    throw "[CPU build] GPU runtime files must not enter the CPU installer: $($paths -join ', ')"
  }
}

$totalBytes = (Get-ChildItem -Path $resourceRoot -Recurse -File | Measure-Object Length -Sum).Sum
$maxBytes = 4GB
if ($totalBytes -gt $maxBytes) {
  throw "Bundled resources are too large: $([math]::Round($totalBytes / 1MB, 1)) MiB (limit: $([math]::Round($maxBytes / 1MB, 1)) MiB)."
}

Write-Host "Bundled resources verified: $([math]::Round($totalBytes / 1MB, 1)) MiB"
