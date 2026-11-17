# Packages extensions into dist\<name>.aseprite-extension (a zip each).
# Usage: powershell -File scripts\build.ps1 [name ...]   (no names = every extension)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force -Path dist | Out-Null

$names = @($args)
if ($names.Count -eq 0) {
  $names = @(Get-ChildItem -Directory extensions |
    Where-Object { Test-Path (Join-Path $_.FullName "package.json") } |
    ForEach-Object { $_.Name })
}
if ($names.Count -eq 0) { throw "No extensions found under extensions\" }

foreach ($name in $names) {
  $dir = Join-Path "extensions" $name
  if (-not (Test-Path (Join-Path $dir "package.json"))) { throw "Unknown extension: $name" }
  $out = "dist\$name.aseprite-extension"
  $tmp = "dist\$name.zip"
  Remove-Item -Force -ErrorAction SilentlyContinue $out, $tmp
  $items = @("package.json", "src", "README.md") | ForEach-Object { Join-Path $dir $_ }
  Compress-Archive -Path $items -DestinationPath $tmp
  Move-Item $tmp $out
  Write-Host "Built $out"
}
