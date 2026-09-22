# Start FE + BE for local fullstack dev
# Usage: .\workspace\scripts\dev.ps1  (from D:\Projects\SF)

$ErrorActionPreference = "Stop"
# workspace/scripts -> SF root
$SfRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BeApiPath = Join-Path $SfRoot "SFBE\src\Web.API"
$FePath = Join-Path $SfRoot "SFFE"

Write-Host "SF dev stack" -ForegroundColor Cyan
Write-Host "  Root: $SfRoot"
Write-Host "  BE:   http://localhost:5272/swagger"
Write-Host "  FE:   http://localhost:5173"
Write-Host ""

if (-not (Test-Path $BeApiPath)) { throw "BE not found: $BeApiPath" }
if (-not (Test-Path (Join-Path $FePath "package.json"))) { throw "FE not found: $FePath" }

Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$BeApiPath'; Write-Host '=== BE ===' -ForegroundColor Green; dotnet run"
)

Start-Sleep -Seconds 2

Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$FePath'; Write-Host '=== FE ===' -ForegroundColor Blue; npm start"
)

Write-Host "Started in separate windows." -ForegroundColor Green
