param(
    [string]$Runtime = "win-x64",
    [switch]$SelfContained
)

$ErrorActionPreference = "Stop"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:DOTNET_NOLOGO = "1"

$projectRoot = Split-Path -Parent $PSScriptRoot
$version = "0.2.0-beta"
$project = Join-Path $projectRoot "windows\XLTD.Vpn.Windows\XLTD.Vpn.Windows.csproj"
$projectDir = Split-Path -Parent $project
$toolsDir = Join-Path $projectDir "tools"
$olcrtcSource = Join-Path $projectRoot ".external\olcrtc"
$tun2socksSource = Join-Path $projectRoot ".external\tun2socks"
$distRoot = Join-Path $projectRoot "dist\windows"
$publishDir = Join-Path $distRoot "XLTD_Vpn_Windows-$version-$Runtime"
$zipPath = Join-Path $distRoot "XLTD_Vpn-Windows-$version-$Runtime.zip"

function Assert-InWorkspace([string]$Path) {
    $root = [System.IO.Path]::GetFullPath($projectRoot)
    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (-not $resolved.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside workspace: $resolved"
    }
}

function Reset-Directory([string]$Path) {
    Assert-InWorkspace $Path
    if (Test-Path $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw "Go is required to build olcrtc.exe"
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK is required to build the Windows GUI"
}

if (-not (Test-Path $olcrtcSource)) {
    throw "Missing local olcrtc source at $olcrtcSource. Rebuild/fetch .external first."
}

if (-not (Test-Path $tun2socksSource)) {
    throw "Missing local tun2socks source at $tun2socksSource. Rebuild/fetch .external first."
}

Reset-Directory $toolsDir
New-Item -ItemType Directory -Force -Path (Join-Path $toolsDir "data") | Out-Null

Push-Location $olcrtcSource
try {
    $olcrtcExe = Join-Path $toolsDir "olcrtc.exe"
    & go build -trimpath -ldflags "-s -w" -o $olcrtcExe ".\cmd\olcrtc"
    if ($LASTEXITCODE -ne 0) {
        throw "go build olcrtc failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Push-Location $tun2socksSource
try {
    $tun2socksExe = Join-Path $toolsDir "tun2socks.exe"
    & go build -trimpath -ldflags "-s -w" -o $tun2socksExe "."
    if ($LASTEXITCODE -ne 0) {
        throw "go build tun2socks failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Copy-Item (Join-Path $olcrtcSource "data\names") (Join-Path $toolsDir "data\names") -Force
Copy-Item (Join-Path $olcrtcSource "data\surnames") (Join-Path $toolsDir "data\surnames") -Force

Reset-Directory $publishDir

$selfContainedValue = if ($SelfContained) { "true" } else { "false" }
& dotnet publish $project -c Release -r $Runtime --self-contained $selfContainedValue -o $publishDir
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

Copy-Item $toolsDir (Join-Path $publishDir "tools") -Recurse -Force

if (Test-Path $zipPath) {
    Assert-InWorkspace $zipPath
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $zipPath -Force
$hash = Get-FileHash $zipPath -Algorithm SHA256

Write-Host "Windows package: $zipPath"
Write-Host "SHA256: $($hash.Hash.ToLowerInvariant())"
