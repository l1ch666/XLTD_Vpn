param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'release'
)

# Build the XLTD VPN Windows desktop app from the Flutter project.
#
# Prerequisites
#   * Flutter SDK on PATH (or installed at C:\src\flutter).
#   * Visual Studio 2022 with "Desktop development with C++" workload.
#     Flutter 3.24.5 does not yet recognise Visual Studio Build Tools 2026.
#   * Developer Mode is NOT required for `flutter build`; it IS required for
#     `flutter run` (plugin builds use symlinks).
#   * Go (for `olcrtc.exe`), and downloaded `wintun.dll`, `tun2socks.exe`,
#     `ffmpeg.exe` next to the built executable under `tools\`.

$ErrorActionPreference = "Stop"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterApp  = Join-Path $projectRoot 'flutter_app'
$flutterBin  = 'C:\src\flutter\bin'

if (Test-Path $flutterBin) {
    $env:Path = "$flutterBin;$env:Path"
}

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    throw 'flutter not on PATH. Install Flutter SDK or add C:\src\flutter\bin.'
}

Push-Location $flutterApp
try {
    Write-Host "Resolving Flutter dependencies..."
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed ($LASTEXITCODE)" }

    Write-Host "Building $Mode Windows desktop..."
    if ($Mode -eq 'release') {
        & flutter build windows --release
    } else {
        & flutter build windows --debug
    }
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows failed ($LASTEXITCODE)`n" +
              "If the error mentions 'Visual Studio 16 2019 could not find any instance of Visual Studio' " +
              "install Visual Studio Community 2022 with the 'Desktop development with C++' workload."
    }

    $pubspec = Get-Content 'pubspec.yaml' -Raw
    $version = [regex]::Match($pubspec, '(?m)^version:\s*(.+)$').Groups[1].Value.Trim()
    if (-not $version) { $version = 'unknown' }
    $version = $version -replace '\+.*$', ''

    $runnerDir = if ($Mode -eq 'release') {
        'build\windows\x64\runner\Release'
    } else {
        'build\windows\x64\runner\Debug'
    }
    if (-not (Test-Path $runnerDir)) { throw "build output not found at $runnerDir" }

    # Copy tools/ next to xltd_vpn.exe.
    $tools = Join-Path $runnerDir 'tools'
    if (Test-Path $tools) { Remove-Item -LiteralPath $tools -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $tools | Out-Null

    $electronTools = Join-Path $projectRoot 'windows\electron-app\tools'
    if (Test-Path $electronTools) {
        Write-Host "Copying tools from existing Electron build..."
        Copy-Item -Path (Join-Path $electronTools '*') -Destination $tools -Recurse -Force
    } else {
        Write-Warning "tools/ not bundled — run scripts\fetch_windows_tools.ps1 first or copy olcrtc.exe + tun2socks.exe + wintun.dll + ffmpeg.exe to $tools manually."
    }

    $dist = Join-Path $projectRoot 'dist\windows'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $zip = Join-Path $dist "XLTD_Vpn-Windows-$version-$Mode-win-x64.zip"
    if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }

    Compress-Archive -Path (Join-Path $runnerDir '*') -DestinationPath $zip -Force
    $hash = Get-FileHash $zip -Algorithm SHA256
    Write-Host "Windows package: $zip"
    Write-Host "SHA256: $($hash.Hash.ToLowerInvariant())"
    Write-Host "Size  : $([math]::Round((Get-Item $zip).Length / 1MB, 2)) MB"
} finally {
    Pop-Location
}
