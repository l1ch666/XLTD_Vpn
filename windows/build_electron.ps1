# build_electron.ps1 — builds XLTD VPN Electron app (portable .exe)
# Run from the XLTD_Vpn\windows directory.
# Requires: Node.js 18+ and npm.

$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Host "── Building XLTD VPN Electron app ──────────────────────────────────" -ForegroundColor Cyan

# Ensure electron-app/node_modules exist
Push-Location "$here\electron-app"
if (!(Test-Path "node_modules")) {
    Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
    npm install
}

# Build portable exe
Write-Host "Running electron-builder (portable win-x64)..." -ForegroundColor Yellow
npx electron-builder --win --x64 --publish never

Pop-Location

# Find the output file
$dist = "$here\dist-electron"
$exe = Get-ChildItem "$dist\*.exe" | Select-Object -First 1
if ($exe) {
    Write-Host ""
    Write-Host "Build complete: $($exe.FullName)" -ForegroundColor Green
    Write-Host "Size: $([math]::Round($exe.Length/1MB,1)) MB" -ForegroundColor Green
} else {
    Write-Error "No .exe found in $dist"
}
