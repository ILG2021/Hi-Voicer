param(
    [ValidateSet("cpu", "cuda")]
    [string]$Variant = "cpu"
)

$ErrorActionPreference = "Stop"

# ──────────────────────────────────────────
#  Release configuration
# ──────────────────────────────────────────
$runtimeTag  = "b9964"
$repoRoot    = Split-Path -Parent $PSScriptRoot

$config = @{
    cpu = @{
        Url           = "https://github.com/ggml-org/llama.cpp/releases/download/$runtimeTag/llama-$runtimeTag-bin-win-cpu-x64.zip"
        Sha256        = "0898A593FACAFC314EAA7FB7F81A343B039F09A7BD133AD8FA884B994A1931C1"
        TargetSuffix  = $runtimeTag          # => engines/llama/b9964/
        # The CPU zip already contains llama-server.exe; no separate DLL package needed
        CudartUrl     = ""
        CudartSha256  = ""
        RequiredFiles = @("llama-server.exe", "llama-server-impl.dll", "llama-common.dll", "llama.dll")
    }
    cuda = @{
        # llama.cpp Windows CUDA 12.4 build (just the EXE + ggml-cuda backend)
        Url           = "https://github.com/ggml-org/llama.cpp/releases/download/$runtimeTag/llama-$runtimeTag-bin-win-cuda-12.4-x64.zip"
        Sha256        = "10346833E0646109040C4461CE44DE35A760565CECB49AA15BE8B900A1C0CBB6"
        # Separate package containing the CUDA 12.4 runtime DLLs
        CudartUrl     = "https://github.com/ggml-org/llama.cpp/releases/download/$runtimeTag/cudart-llama-bin-win-cuda-12.4-x64.zip"
        CudartSha256  = "8C79A9B226DE4B3CACFD1F83D24F962D0773BE79F1E7B75C6AF4DED7E32AE1D6"
        TargetSuffix  = "$runtimeTag-cuda"   # => engines/llama/b9964-cuda/
        RequiredFiles = @("llama-server.exe", "llama-server-impl.dll", "llama-common.dll", "llama.dll", "ggml-cuda.dll")
    }
}

$cfg        = $config[$Variant]
$targetDir  = Join-Path $repoRoot "src-tauri\resources\engines\llama\$($cfg.TargetSuffix)"

Write-Host "Preparing llama.cpp runtime: $Variant ($runtimeTag)" -ForegroundColor Cyan

# ──────────────────────────────────────────
#  Skip if already present
# ──────────────────────────────────────────
$missingRequired = @($cfg.RequiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $targetDir $_)) })
$cudaRuntimeReady = $Variant -ne "cuda" -or @(Get-ChildItem -LiteralPath $targetDir -Filter "*cudart*.dll" -File -ErrorAction SilentlyContinue).Count -gt 0
if ($missingRequired.Count -eq 0 -and $cudaRuntimeReady) {
    Write-Host "llama-server.exe already present at $targetDir — skipping download." -ForegroundColor Green
    exit 0
}

# ──────────────────────────────────────────
#  Helper: download + verify + extract zip
# ──────────────────────────────────────────
function Get-VerifiedZip {
    param(
        [string]$Url,
        [string]$ExpectedSha256,
        [string]$ExtractTo
    )
    $archiveName = ($Url -split '/')[-1]
    $archivePath = Join-Path $env:TEMP $archiveName
    $extractDir  = Join-Path $env:TEMP ($archiveName -replace '\.zip$', '')

    Write-Host "Downloading $archiveName ..."
    Invoke-WebRequest -Uri $Url -OutFile $archivePath

    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedSha256.ToUpper()) {
        throw "Checksum mismatch for $archiveName.`n  Expected: $ExpectedSha256`n  Got:      $actualHash"
    }
    Write-Host "SHA256 verified: $archiveName" -ForegroundColor Green

    if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
    return $extractDir
}

# ──────────────────────────────────────────
#  Create target directory
# ──────────────────────────────────────────
if (Test-Path -LiteralPath $targetDir) { Remove-Item -LiteralPath $targetDir -Recurse -Force }
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

# ──────────────────────────────────────────
#  Download & extract main package
# ──────────────────────────────────────────
$extractDir = Get-VerifiedZip -Url $cfg.Url -ExpectedSha256 $cfg.Sha256 -ExtractTo $env:TEMP

# Find llama-server.exe (may be in a sub-folder)
$exeFiles = Get-ChildItem -LiteralPath $extractDir -Recurse -Filter "llama-server.exe"
if ($exeFiles.Count -eq 0) {
    throw "llama-server.exe was not found in $($cfg.Url)"
}
$exeSourceDir = $exeFiles[0].DirectoryName
Write-Host "Found llama-server.exe at $exeSourceDir"

foreach ($file in $cfg.RequiredFiles) {
    $src = Join-Path $exeSourceDir $file
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $targetDir $file) -Force
        Write-Host "  Copied $file"
    } else {
        Write-Warning "  Not found, skipping: $file"
    }
}

# Copy all DLLs sitting next to llama-server.exe (e.g. ggml-cuda.dll, ggml.dll)
Get-ChildItem -LiteralPath $exeSourceDir -Filter "*.dll" | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetDir $_.Name) -Force
    Write-Host "  Copied $($_.Name)"
}

# ──────────────────────────────────────────
#  CUDA variant: also unpack the cudart DLLs
# ──────────────────────────────────────────
if ($Variant -eq "cuda" -and $cfg.CudartUrl -ne "") {
    $cudartDir = Get-VerifiedZip -Url $cfg.CudartUrl -ExpectedSha256 $cfg.CudartSha256 -ExtractTo $env:TEMP
    Get-ChildItem -LiteralPath $cudartDir -Recurse -Filter "*.dll" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetDir $_.Name) -Force
        Write-Host "  Copied cudart DLL: $($_.Name)"
    }
}

# ──────────────────────────────────────────
#  Report
# ──────────────────────────────────────────
$totalBytes = (Get-ChildItem -LiteralPath $targetDir -File | Measure-Object Length -Sum).Sum
Write-Host ("Prepared llama.cpp $Variant runtime ({0:N1} MiB) -> $targetDir" -f ($totalBytes / 1MB)) -ForegroundColor Green
