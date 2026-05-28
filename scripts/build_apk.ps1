param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'debug'
)

# Build the XLTD VPN Android APK from the Flutter project.
#
# Prerequisites
#   * Flutter SDK on PATH (or installed at C:\src\flutter).
#   * Android SDK at $LOCALAPPDATA\Android\Sdk.
#   * Android Studio bundled JBR (JDK 21) at
#     C:\Program Files\Android\Android Studio\jbr.

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterApp  = Join-Path $projectRoot 'flutter_app'
$sdk         = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$studioJbr   = 'C:\Program Files\Android\Android Studio\jbr'
$flutterBin  = 'C:\src\flutter\bin'

if (-not (Test-Path $sdk)) { throw "Android SDK not found at $sdk" }

if (Test-Path $studioJbr) {
    $env:JAVA_HOME = $studioJbr
    $env:Path = (Join-Path $studioJbr 'bin') + ";$env:Path"
}
if (Test-Path $flutterBin) {
    $env:Path = "$flutterBin;$env:Path"
}

$env:ANDROID_HOME     = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    throw 'flutter not on PATH. Install Flutter SDK or add C:\src\flutter\bin.'
}

Push-Location $flutterApp
try {
    Write-Host "Resolving Flutter dependencies..."
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed ($LASTEXITCODE)" }

    Write-Host "Building $Mode APK..."
    if ($Mode -eq 'release') {
        & flutter build apk --release
    } else {
        & flutter build apk --debug
    }
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed ($LASTEXITCODE)" }

    $gradleFile  = Get-Content 'android\app\build.gradle' -Raw
    $versionName = [regex]::Match($gradleFile, 'versionName\s*=\s*"([^"]+)"').Groups[1].Value
    if (-not $versionName) { $versionName = 'unknown' }

    $sourceApk = if ($Mode -eq 'release') {
        'build\app\outputs\flutter-apk\app-release.apk'
    } else {
        'build\app\outputs\flutter-apk\app-debug.apk'
    }
    if (-not (Test-Path $sourceApk)) { throw "APK not found at $sourceApk" }

    $dist = Join-Path $projectRoot 'dist'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $outApk = Join-Path $dist "XLTD_Vpn-$versionName-$Mode.apk"
    Copy-Item $sourceApk $outApk -Force
    Write-Host "APK: $outApk"
    $hash = Get-FileHash $outApk -Algorithm SHA256
    Write-Host "SHA256: $($hash.Hash.ToLowerInvariant())"
    Write-Host "Size  : $([math]::Round((Get-Item $outApk).Length / 1MB, 2)) MB"
} finally {
    Pop-Location
}
