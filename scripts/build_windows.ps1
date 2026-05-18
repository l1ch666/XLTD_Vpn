param(
    [string]$Runtime = "win-x64",
    [switch]$SelfContained
)

$ErrorActionPreference = "Stop"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:DOTNET_NOLOGO = "1"

$projectRoot = Split-Path -Parent $PSScriptRoot
$version = "0.3.0-beta"
$project = Join-Path $projectRoot "windows\XLTD.Vpn.Windows\XLTD.Vpn.Windows.csproj"
$projectDir = Split-Path -Parent $project
$toolsDir = Join-Path $projectDir "tools"
$olcrtcSource = Join-Path $projectRoot ".external\olcrtc"
$tun2socksSource = Join-Path $projectRoot ".external\tun2socks"
$ffmpegCacheDir = Join-Path $projectRoot ".external\ffmpeg"
$ffmpegZip = Join-Path $ffmpegCacheDir "ffmpeg-release-essentials.zip"
$ffmpegExtractDir = Join-Path $ffmpegCacheDir "extract"
$ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$olcrtcPatch = Join-Path $projectRoot "patches\olcrtc-vp8-legacy-binding.patch"
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

function Resolve-Ffmpeg {
    if ($env:FFMPEG_PATH -and (Test-Path $env:FFMPEG_PATH)) {
        return (Resolve-Path $env:FFMPEG_PATH).Path
    }

    $command = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($command -and $command.Source -and (Test-Path $command.Source)) {
        return $command.Source
    }

    $cached = Join-Path $ffmpegCacheDir "ffmpeg.exe"
    if (Test-Path $cached) {
        return $cached
    }

    New-Item -ItemType Directory -Force -Path $ffmpegCacheDir | Out-Null
    if (-not (Test-Path $ffmpegZip)) {
        Write-Host "Downloading ffmpeg for videochannel support..."
        Invoke-WebRequest -Uri $ffmpegUrl -OutFile $ffmpegZip
    }

    Reset-Directory $ffmpegExtractDir
    Expand-Archive -LiteralPath $ffmpegZip -DestinationPath $ffmpegExtractDir -Force
    $ffmpeg = Get-ChildItem -Path $ffmpegExtractDir -Recurse -Filter ffmpeg.exe | Select-Object -First 1
    if (-not $ffmpeg) {
        throw "Downloaded ffmpeg archive did not contain ffmpeg.exe"
    }

    Copy-Item $ffmpeg.FullName $cached -Force
    return $cached
}

function Apply-GitPatchIfNeeded([string]$Repo, [string]$Patch) {
    if (-not (Test-Path $Patch)) {
        return
    }

    Push-Location $Repo
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & git apply --check $Patch *> $null
        $applyCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($applyCode -eq 0) {
            Write-Host "Applying local olcRTC compatibility patch: $Patch"
            & git apply $Patch
            if ($LASTEXITCODE -ne 0) {
                throw "git apply failed with exit code $LASTEXITCODE"
            }
            return
        }

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & git apply --reverse --check --ignore-space-change --ignore-whitespace $Patch *> $null
        $reverseCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        if ($reverseCode -eq 0) {
            Write-Host "Local olcRTC compatibility patch already applied."
            return
        }

        throw "Local olcRTC compatibility patch does not apply cleanly: $Patch"
    } finally {
        Pop-Location
    }
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

Apply-GitPatchIfNeeded $olcrtcSource $olcrtcPatch

$ffmpegSource = Resolve-Ffmpeg

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
Copy-Item $ffmpegSource (Join-Path $toolsDir "ffmpeg.exe") -Force

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
