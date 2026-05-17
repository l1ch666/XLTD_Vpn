param(
    [string]$Task = ":app:assembleDebug"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$studioJbr = "C:\Program Files\Android\Android Studio\jbr"
$preferredGradle = Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-9.0.0-bin"

if (-not (Test-Path $sdk)) {
    throw "Android SDK not found at $sdk"
}

if (Test-Path $studioJbr) {
    $env:JAVA_HOME = $studioJbr
    $env:Path = (Join-Path $studioJbr "bin") + ";$env:Path"
}

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

$gradle = Get-Command gradle -ErrorAction SilentlyContinue
if ($gradle) {
    $gradleExe = $gradle.Source
} else {
    $gradleExe = Get-ChildItem $preferredGradle -Recurse -Filter gradle.bat -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName -First 1
}

if (-not $gradleExe) {
    throw "Gradle executable not found. Install Gradle or run Android Studio once so Gradle is cached."
}

Push-Location $projectRoot
try {
    & $gradleExe $Task --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle task failed with exit code $LASTEXITCODE"
    }

    $gradleFile = Get-Content "app\build.gradle" -Raw
    $versionName = [regex]::Match($gradleFile, "versionName\s+'([^']+)'").Groups[1].Value
    if (-not $versionName) {
        $versionName = "unknown"
    }

    $sourceApk = "app\build\outputs\apk\debug\app-debug.apk"
    if (-not (Test-Path $sourceApk)) {
        throw "Expected APK not found at $sourceApk"
    }

    New-Item -ItemType Directory -Force -Path "dist" | Out-Null
    $outApk = "dist\XLTD_Vpn-$versionName-debug.apk"
    Copy-Item $sourceApk $outApk -Force
    Write-Host "APK: $outApk"
} finally {
    Pop-Location
}
