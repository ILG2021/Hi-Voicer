$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoots = @(
  (Join-Path $repoRoot "src"),
  (Join-Path $repoRoot "src-tauri\src")
)
$sourceFiles = Get-ChildItem -LiteralPath $runtimeRoots -Recurse -File | Where-Object {
  $_.Extension -in @(".rs", ".ts", ".tsx", ".js", ".py")
}
$publicUrls = Select-String -LiteralPath $sourceFiles.FullName -Pattern 'https?://[^\s"'']+' -AllMatches |
  Where-Object { $_.Line -notmatch 'http://127\.0\.0\.1:' }

if ($publicUrls) {
  $publicUrls | Format-Table Path, LineNumber, Line -AutoSize
  throw "Runtime source contains a public network URL. Public downloads are only allowed in build-time preparation scripts."
}

Write-Host "Runtime offline policy verified: no public network URLs found."
