<#
.SYNOPSIS
  Builds CPU and/or CUDA installer variants for Hi-Voicer.

.DESCRIPTION
  Orchestrates one or two Tauri NSIS builds, each with the correct
  llama.cpp runtime bundled. Finished installers are collected in dist-builds/.

  CPU  build => Hi-Voicer_<version>_x64-setup.exe
  CUDA build => Hi-Voicer CUDA_<version>_x64-setup.exe

.PARAMETER Variant
  Which variant(s) to build: cpu | cuda | both  (default: both)

.EXAMPLE
  .\build-variants.ps1 -Variant cpu
  .\build-variants.ps1 -Variant cuda
  .\build-variants.ps1 -Variant both
#>
param(
    [ValidateSet("cpu", "cuda", "both")]
    [string]$Variant = "both"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "     Hi-Voicer Multi-Variant Builder      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------
#  Step 1: Common resources (download once)
# ------------------------------------------
Write-Host "[*] Verifying offline policy..." -ForegroundColor Yellow
& (Join-Path $PSScriptRoot "check-runtime-offline.ps1")
Write-Host ""

Write-Host "[*] Preparing shared resources (ffmpeg, sherpa, models)..." -ForegroundColor Yellow
& (Join-Path $PSScriptRoot "prepare-ffmpeg-runtime.ps1")
& (Join-Path $PSScriptRoot "prepare-sherpa-runtime.ps1")
& (Join-Path $PSScriptRoot "prepare-offline-models.ps1")
Write-Host "[OK] Shared resources ready." -ForegroundColor Green
Write-Host ""

# Output directory for final installers
$outDir = Join-Path $root "dist-builds"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# ------------------------------------------
#  Build function (one variant at a time)
# ------------------------------------------
function Invoke-VariantBuild {
    param([string]$BuildVariant)

    $productName     = if ($BuildVariant -eq "cuda") { "Hi-Voicer CUDA" } else { "Hi-Voicer" }
    $variantLabel    = $BuildVariant.ToUpper()
    $llamaEnginesDir = Join-Path $root "src-tauri\resources\engines\llama"

    Write-Host "------------------------------------------" -ForegroundColor Magenta
    Write-Host "  Building: $variantLabel  (productName: $productName)" -ForegroundColor Magenta
    Write-Host "------------------------------------------" -ForegroundColor Magenta

    # -- 1. Remove the OTHER variant's llama dir to avoid bundling both --
    if ($BuildVariant -eq "cuda") {
        $otherDir = Join-Path $llamaEnginesDir "b9964"
        if (Test-Path -LiteralPath $otherDir) {
            Write-Host "  Removing CPU llama dir to keep CUDA-only bundle..." -ForegroundColor DarkGray
            Remove-Item -LiteralPath $otherDir -Recurse -Force
        }
    } else {
        $otherDir = Join-Path $llamaEnginesDir "b9964-cuda"
        if (Test-Path -LiteralPath $otherDir) {
            Write-Host "  Removing CUDA llama dir to keep CPU-only bundle..." -ForegroundColor DarkGray
            Remove-Item -LiteralPath $otherDir -Recurse -Force
        }
    }

    # -- 2. Download / verify the correct llama runtime --
    Write-Host "[*] Preparing llama.cpp [$BuildVariant] runtime..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "prepare-llama-runtime.ps1") -Variant $BuildVariant
    Write-Host ""

    # -- 3. Export env var so check-bundled-resources.ps1 knows the variant --
    $env:HIVOICER_BUILD_VARIANT = $BuildVariant

    # -- 4. Run Tauri build, overriding productName via a temp config file --
    #        (inline JSON via --config loses quotes through npm -> tauri on Windows)
    $tempConfig = Join-Path $env:TEMP ("hivoicer-build-config-{0}.json" -f $BuildVariant)
    @{ productName = $productName } | ConvertTo-Json -Compress | Set-Content -Path $tempConfig -Encoding UTF8
    Write-Host "[*] Running tauri build [$variantLabel] (config: $tempConfig)..." -ForegroundColor Yellow

    Push-Location $root
    try {
        npm run tauri -- build --config $tempConfig
        if ($LASTEXITCODE -ne 0) {
            throw "Tauri build failed for variant: $BuildVariant (exit code $LASTEXITCODE)"
        }
    } finally {
        Pop-Location
        Remove-Item -Path $tempConfig -ErrorAction SilentlyContinue
        $env:HIVOICER_BUILD_VARIANT = ""
    }

    # -- 5. Locate the freshly built MSI and copy to dist-builds/ --
    $msiDir = Join-Path $root "src-tauri\target\release\bundle\msi"
    $installer = Get-ChildItem -Path $msiDir -Filter "*.msi" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

    if (-not $installer) {
        throw "MSI installer not found in: $msiDir"
    }

    $destPath = Join-Path $outDir $installer.Name
    Copy-Item -LiteralPath $installer.FullName -Destination $destPath -Force
    $sizeMB   = [math]::Round($installer.Length / 1MB, 1)
    $sizeText = "{0} MiB" -f $sizeMB
    Write-Host ("[OK] [$variantLabel] Installer saved: dist-builds\{0} ({1})" -f $installer.Name, $sizeText) -ForegroundColor Green
    Write-Host ""
}

# ------------------------------------------
#  Run selected variant(s)
# ------------------------------------------
$toBuild = if ($Variant -eq "both") { @("cpu", "cuda") } else { @($Variant) }
foreach ($v in $toBuild) {
    Invoke-VariantBuild -BuildVariant $v
}

# ------------------------------------------
#  Summary
# ------------------------------------------
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  All builds complete!  Artifacts: dist-builds/" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Get-ChildItem -Path $outDir -Filter "*.exe" | ForEach-Object {
    $sizeMB   = [math]::Round($_.Length / 1MB, 1)
    $sizeText = "{0} MiB" -f $sizeMB
    Write-Host ("  {0}  ({1})" -f $_.Name, $sizeText) -ForegroundColor White
}
Write-Host ""
