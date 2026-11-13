# Packages the extension into dist\lachesis.aseprite-extension (a zip).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force -Path dist | Out-Null
$out = "dist\lachesis.aseprite-extension"
$tmp = "dist\lachesis.zip"
Remove-Item -Force -ErrorAction SilentlyContinue $out, $tmp
Compress-Archive -Path package.json, src, README.md -DestinationPath $tmp
Move-Item $tmp $out
Write-Host "Built $out"
