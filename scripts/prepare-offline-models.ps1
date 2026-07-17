$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelsRoot = Join-Path $repoRoot "src-tauri\resources\models"
$senseRevision = "2365baeacb507f821a0c8120fcee3d484dba7a07"


function Install-VerifiedFile {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$Sha256
  )

  if (Test-Path -LiteralPath $Destination) {
    $existingHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($existingHash -eq $Sha256) {
      Write-Host "Verified existing model file: $Destination"
      return
    }
    Remove-Item -LiteralPath $Destination -Force
  }

  $parent = Split-Path -Parent $Destination
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  $partial = "$Destination.download"
  Invoke-WebRequest -Uri $Url -OutFile $partial
  $actualHash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
  if ($actualHash -ne $Sha256) {
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    throw "Model checksum mismatch for $Url. Expected $Sha256, got $actualHash."
  }
  Move-Item -LiteralPath $partial -Destination $Destination -Force
}

$senseDir = Join-Path $modelsRoot "sensevoice-small"
Install-VerifiedFile `
  -Url "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/$senseRevision/model.int8.onnx" `
  -Destination (Join-Path $senseDir "model.int8.onnx") `
  -Sha256 "C71F0CE00BEC95B07744E116345E33D8CBBE08CEF896382CF907BF4B51A2CD51"

$tokensUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/$senseRevision/tokens.txt"
$tokensPath = Join-Path $senseDir "tokens.txt"
$tokensPartial = "$tokensPath.download"
New-Item -ItemType Directory -Path $senseDir -Force | Out-Null
Invoke-WebRequest -Uri $tokensUrl -OutFile $tokensPartial
$tokensText = Get-Content -Raw -LiteralPath $tokensPartial
$tokensBytes = (Get-Item -LiteralPath $tokensPartial).Length
if ($tokensBytes -lt 300KB -or $tokensBytes -gt 330KB -or $tokensText -match "<html") {
  Remove-Item -LiteralPath $tokensPartial -Force -ErrorAction SilentlyContinue
  throw "SenseVoice tokens file from the pinned revision is invalid."
}
Move-Item -LiteralPath $tokensPartial -Destination $tokensPath -Force

$senseConfig = @{
  engine = "sherpa-onnx"
  modelId = "sensevoice-small"
  modelName = "SenseVoiceSmall"
  modelDir = ""
  executable = ""
  args = '--tokens="{modelDir}\tokens.txt" --sense-voice-model="{modelDir}\model.int8.onnx" --sense-voice-use-itn=1 --num-threads=4'
  requiredFiles = @("model.int8.onnx", "tokens.txt")
} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText(
  (Join-Path $senseDir "engine.json"),
  $senseConfig,
  (New-Object Text.UTF8Encoding($false))
)

$qwenDir = Join-Path $modelsRoot "qwen3-asr-0.6b"
New-Item -ItemType Directory -Path $qwenDir -Force | Out-Null

# Qwen3-ASR 0.6B Q8_0 GGUF — main model
Install-VerifiedFile `
  -Url "https://huggingface.co/ggml-org/Qwen3-ASR-0.6B-GGUF/resolve/main/Qwen3-ASR-0.6B-Q8_0.gguf" `
  -Destination (Join-Path $qwenDir "Qwen3-ASR-0.6B-Q8_0.gguf") `
  -Sha256 "BCA259818B50CA7C4C05E9BDB35A5DC04FA039653A6D6F3F0F331F96F6AA1971"

# Qwen3-ASR 0.6B Q8_0 GGUF — audio multimodal projector (mmproj)
Install-VerifiedFile `
  -Url "https://huggingface.co/ggml-org/Qwen3-ASR-0.6B-GGUF/resolve/main/mmproj-Qwen3-ASR-0.6B-Q8_0.gguf" `
  -Destination (Join-Path $qwenDir "mmproj-Qwen3-ASR-0.6B-Q8_0.gguf") `
  -Sha256 "41A342B5E4C514E968CB756DE6CD1B7BE39EFF43C44C57A2EF5FC6522E36603D"

$qwenConfig = @{
  engine        = "llama-server"
  modelId       = "qwen3-asr-0.6b"
  modelName     = "Qwen3-ASR 0.6B"
  modelDir      = ""
  executable    = ""
  args          = ""
  requiredFiles = @("Qwen3-ASR-0.6B-Q8_0.gguf", "mmproj-Qwen3-ASR-0.6B-Q8_0.gguf")
} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText(
  (Join-Path $qwenDir "engine.json"),
  $qwenConfig,
  (New-Object Text.UTF8Encoding($false))
)

Write-Host "Prepared offline models under $modelsRoot"
