function Get-FileSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $stream = $null
  $sha256 = $null
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash($stream)
    return ([System.BitConverter]::ToString($hash)).Replace("-", "")
  }
  finally {
    if ($sha256) {
      $sha256.Dispose()
    }
    if ($stream) {
      $stream.Dispose()
    }
  }
}

function Test-FileSha256 {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256
  )

  return (Test-Path -LiteralPath $Path -PathType Leaf) -and
    ((Get-FileSha256 -Path $Path) -eq $ExpectedSha256.ToUpperInvariant())
}

function Save-VerifiedDownload {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$Sha256
  )

  $expected = $Sha256.ToUpperInvariant()
  if (Test-FileSha256 -Path $Destination -ExpectedSha256 $expected) {
    Write-Host "Using verified cached file: $Destination"
    return
  }
  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Force
  }

  $parent = Split-Path -Parent $Destination
  if ($parent) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  $partial = "$Destination.download"
  if (Test-FileSha256 -Path $partial -ExpectedSha256 $expected) {
    Move-Item -LiteralPath $partial -Destination $Destination -Force
    Write-Host "Recovered verified partial download: $Destination"
    return
  }
  if (Test-Path -LiteralPath $partial) {
    Remove-Item -LiteralPath $partial -Force
  }

  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $partial
  $actual = Get-FileSha256 -Path $partial
  if ($actual -ne $expected) {
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    throw "Checksum mismatch for $Url. Expected $expected, got $actual."
  }
  Move-Item -LiteralPath $partial -Destination $Destination -Force
}
