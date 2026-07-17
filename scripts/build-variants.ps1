<#
.SYNOPSIS
  Builds CPU (NSIS) and/or CUDA (Inno Setup) installer variants for Hi-Voicer.

.DESCRIPTION
  CPU  variant => Tauri NSIS    => Hi-Voicer_<ver>_x64-setup.exe
  CUDA variant => Inno Setup    => Hi-Voicer CUDA_<ver>_x64-setup.exe
                  (full cudart bundled; no system CUDA Toolkit required)

.PARAMETER Variant
  cpu | cuda | both  (default: both)

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
#  Helper: read version from package.json
# ------------------------------------------
$appVersion = (Get-Content -Raw (Join-Path $root "package.json") | ConvertFrom-Json).version
Write-Host "[*] App version: $appVersion" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------
#  Helper: find Inno Setup ISCC.exe
# ------------------------------------------
function Find-IsccPath {
    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
        "C:\Program Files\Inno Setup 5\ISCC.exe"
    )
    $fromPath = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    throw "Inno Setup (ISCC.exe) not found. Please install Inno Setup 6: https://jrsoftware.org/isdl.php"
}

# ------------------------------------------
#  Helper: pre-flight check before ISCC
# ------------------------------------------
function Test-IssSourceFiles {
    param([string]$SourceRoot)
    Write-Host "[*] Pre-flight: checking Inno Setup source files..." -ForegroundColor Yellow
    $required = @(
        "src-tauri\target\release\hi-voicer.exe",
        "src-tauri\icons\icon.ico",
        "src-tauri\resources"
    )
    $missing = @()
    foreach ($rel in $required) {
        $abs = Join-Path $SourceRoot $rel
        if (-not (Test-Path -LiteralPath $abs)) {
            $missing += $rel
        }
    }
    $wv2 = Join-Path $SourceRoot ".tmp\webview2\MicrosoftEdgeWebview2Setup.exe"
    if (-not (Test-Path -LiteralPath $wv2)) {
        Write-Host "  [WARN] WebView2 bootstrapper not found -- will skip it in installer." -ForegroundColor DarkYellow
    } else {
        Write-Host "  WebView2 bootstrapper: OK" -ForegroundColor DarkGray
    }
    if ($missing.Count -gt 0) {
        Write-Host "[!] Missing files required by Inno Setup:" -ForegroundColor Red
        foreach ($m in $missing) { Write-Host "    - $m" -ForegroundColor Red }
        throw "Pre-flight failed: $($missing.Count) file(s) missing (see above)"
    }
    Write-Host "  All required source files present." -ForegroundColor DarkGray
}

# ------------------------------------------
#  Step 1: Shared resources (once)
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

# Output directory
$outDir = Join-Path $root "dist-builds"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# ==========================================================
#  CPU build  --  Tauri NSIS  (bundle is small enough)
# ==========================================================
function Invoke-CpuBuild {
    Write-Host "------------------------------------------" -ForegroundColor Magenta
    Write-Host "  Building: CPU  (NSIS installer)" -ForegroundColor Magenta
    Write-Host "------------------------------------------" -ForegroundColor Magenta

    $llamaEnginesDir = Join-Path $root "src-tauri\resources\engines\llama"

    # Remove CUDA llama dir so it is not accidentally bundled
    $otherDir = Join-Path $llamaEnginesDir "b9964-cuda"
    if (Test-Path -LiteralPath $otherDir) {
        Write-Host "  Removing CUDA llama dir (CPU-only bundle)..." -ForegroundColor DarkGray
        Remove-Item -LiteralPath $otherDir -Recurse -Force
    }

    Write-Host "[*] Preparing llama.cpp [cpu] runtime..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "prepare-llama-runtime.ps1") -Variant cpu
    Write-Host ""

    $env:HIVOICER_BUILD_VARIANT = "cpu"
    $tempConfig = Join-Path $env:TEMP "hivoicer-build-config-cpu.json"
    @{ productName = "Hi-Voicer" } | ConvertTo-Json -Compress | Set-Content -Path $tempConfig -Encoding UTF8

    Push-Location $root
    try {
        npm run tauri -- build --config $tempConfig
        if ($LASTEXITCODE -ne 0) { throw "Tauri NSIS build failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
        Remove-Item -Path $tempConfig -ErrorAction SilentlyContinue
        $env:HIVOICER_BUILD_VARIANT = ""
    }

    $nsisDir = Join-Path $root "src-tauri\target\release\bundle\nsis"
    $installer = Get-ChildItem -Path $nsisDir -Filter "*-setup.exe" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $installer) { throw "NSIS installer not found in: $nsisDir" }

    $destPath = Join-Path $outDir $installer.Name
    Copy-Item -LiteralPath $installer.FullName -Destination $destPath -Force
    $sizeText = "{0} MiB" -f [math]::Round($installer.Length / 1MB, 1)
    Write-Host ("[OK] [CPU] Installer saved: dist-builds\{0} ({1})" -f $installer.Name, $sizeText) -ForegroundColor Green
    Write-Host ""
}

# ==========================================================
#  CUDA build  --  Inno Setup  (handles large bundles)
#               cudart DLLs fully bundled; no system CUDA needed
# ==========================================================
function Invoke-CudaBuild {
    Write-Host "------------------------------------------" -ForegroundColor Magenta
    Write-Host "  Building: CUDA  (Inno Setup installer)" -ForegroundColor Magenta
    Write-Host "------------------------------------------" -ForegroundColor Magenta

    $llamaEnginesDir = Join-Path $root "src-tauri\resources\engines\llama"

    # -- 1. Locate Inno Setup --
    Write-Host "[*] Locating Inno Setup..." -ForegroundColor Yellow
    $iscc = Find-IsccPath
    Write-Host "  Found: $iscc" -ForegroundColor DarkGray
    Write-Host ""

    # -- 2. Remove CPU llama dir so it is not bundled --
    Write-Host "[*] Preparing llama.cpp [cuda] runtime (full, incl. cudart)..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "prepare-llama-runtime.ps1") -Variant cuda
    Write-Host ""

    # -- 5. Resource validation --
    $env:HIVOICER_BUILD_VARIANT = "cuda"
    Write-Host "[*] Validating bundled resources..." -ForegroundColor Yellow
    npm run check:resources
    if ($LASTEXITCODE -ne 0) { throw "check:resources failed for CUDA variant" }
    Write-Host ""

    # -- 6. Build frontend --
    Write-Host "[*] Building frontend..." -ForegroundColor Yellow
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Frontend build (npm run build) failed" }
    Write-Host ""

    # -- 7. Compile Rust binary (embeds built frontend from dist/) --
    Write-Host "[*] Compiling Rust binary (cargo build --release)..." -ForegroundColor Yellow
    Push-Location $root
    try {
        cargo build --release --manifest-path src-tauri/Cargo.toml
        if ($LASTEXITCODE -ne 0) { throw "cargo build --release failed" }
    } finally {
        Pop-Location
        $env:HIVOICER_BUILD_VARIANT = ""
    }
    Write-Host ""

    # -- 8. Pre-flight: verify all source files exist before calling ISCC --
    Test-IssSourceFiles -SourceRoot $root

    # -- 9. Run Inno Setup --
    Write-Host "[*] Running Inno Setup (ISCC)..." -ForegroundColor Yellow
    $issFile = Join-Path $PSScriptRoot "hivoicer.iss"
    Write-Host "  iscc   : $iscc" -ForegroundColor DarkGray
    Write-Host "  issFile: $issFile" -ForegroundColor DarkGray
    Write-Host "  root   : $root" -ForegroundColor DarkGray
    # /O+ = verbose file output listing (helps diagnose missing-file errors)
    & $iscc `
        "/O+" `
        "/DAppVariantSuffix= CUDA" `
        "/DAppVersion=$appVersion" `
        "/DSourceRoot=$root" `
        $issFile
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup (ISCC) failed (exit $LASTEXITCODE)" }

    # -- 9. Verify output --
    $exeName = "Hi-Voicer CUDA_{0}_x64-setup.exe" -f $appVersion
    $outFile  = Join-Path $outDir $exeName
    if (-not (Test-Path -LiteralPath $outFile)) {
        # ISCC may produce slightly different filename; find it
        $found = Get-ChildItem -Path $outDir -Filter "*CUDA*setup*.exe" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $found) { throw "Inno Setup output not found in dist-builds/" }
        $outFile = $found.FullName
        $exeName = $found.Name
    }
    $sizeText = "{0} MiB" -f [math]::Round((Get-Item $outFile).Length / 1MB, 1)
    Write-Host ("[OK] [CUDA] Installer saved: dist-builds\{0} ({1})" -f $exeName, $sizeText) -ForegroundColor Green
    Write-Host ""
}

# ------------------------------------------
#  Run selected variant(s)
# ------------------------------------------
$toBuild = if ($Variant -eq "both") { @("cpu", "cuda") } else { @($Variant) }
foreach ($v in $toBuild) {
    if ($v -eq "cpu")  { Invoke-CpuBuild }
    if ($v -eq "cuda") { Invoke-CudaBuild }
}

# ------------------------------------------
#  Summary
# ------------------------------------------
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  All builds complete!  Artifacts: dist-builds/" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Get-ChildItem -Path $outDir -Filter "*.exe" | ForEach-Object {
    $sizeText = "{0} MiB" -f [math]::Round($_.Length / 1MB, 1)
    Write-Host ("  {0}  ({1})" -f $_.Name, $sizeText) -ForegroundColor White
}
Write-Host ""
