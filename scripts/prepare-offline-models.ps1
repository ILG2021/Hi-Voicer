$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "hash-utils.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$modelsRoot = Join-Path $repoRoot "src-tauri\resources\models"
$senseRevision = "2365baeacb507f821a0c8120fcee3d484dba7a07"
$paraformerRevision = "888ddb4"
$tokensSha256 = "F449EB28DC567533D7FA59BE34E2ABCA8784F771850C78A47FB731A31429A1DC"
$vadSha256 = "9E2449E1087496D8D4CABA907F23E0BD3F78D91FA552479BB9C23AC09CBB1FD6"


function Install-VerifiedFile {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$Sha256
  )

  Save-VerifiedDownload -Url $Url -Destination $Destination -Sha256 $Sha256
}

$senseDir = Join-Path $modelsRoot "sensevoice-small"
Install-VerifiedFile `
  -Url "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/$senseRevision/model.int8.onnx" `
  -Destination (Join-Path $senseDir "model.int8.onnx") `
  -Sha256 "C71F0CE00BEC95B07744E116345E33D8CBBE08CEF896382CF907BF4B51A2CD51"

$tokensUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/$senseRevision/tokens.txt"
$tokensPath = Join-Path $senseDir "tokens.txt"
Install-VerifiedFile -Url $tokensUrl -Destination $tokensPath -Sha256 $tokensSha256

Install-VerifiedFile `
  -Url "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx" `
  -Destination (Join-Path $modelsRoot "silero_vad.onnx") `
  -Sha256 $vadSha256

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

$paraformerDir = Join-Path $modelsRoot "sherpa-paraformer-zh"
$paraformerBaseUrl = "https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14/resolve/$paraformerRevision"
Install-VerifiedFile `
  -Url "$paraformerBaseUrl/model.int8.onnx" `
  -Destination (Join-Path $paraformerDir "model.int8.onnx") `
  -Sha256 "C3207EF14440AAC412A8478A39E232D46A5B877CDD801D0DD680554930B66F9E"
Install-VerifiedFile `
  -Url "$paraformerBaseUrl/tokens.txt" `
  -Destination (Join-Path $paraformerDir "tokens.txt") `
  -Sha256 "59ABA8873A2ED1E122C25FEE421E25F283B63290EFBDE85C1F01A853D83CB6E6"
Install-VerifiedFile `
  -Url "$paraformerBaseUrl/am.mvn" `
  -Destination (Join-Path $paraformerDir "am.mvn") `
  -Sha256 "29B3C740A2C0CFC6B308126D31D7F265FA2BE74F3BB095CD2F143EA970896AE5"

$paraformerConfig = @{
  engine        = "sherpa-onnx"
  modelId       = "sherpa-paraformer-zh"
  modelName     = "Paraformer 中文"
  modelDir      = ""
  executable    = ""
  args          = '--tokens="{modelDir}\tokens.txt" --paraformer-model="{modelDir}\model.int8.onnx" --num-threads=4'
  requiredFiles = @("model.int8.onnx", "tokens.txt", "am.mvn")
} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText(
  (Join-Path $paraformerDir "engine.json"),
  $paraformerConfig,
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
