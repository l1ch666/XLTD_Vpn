param(
    [string]$Runtime = "win-x64",
    [switch]$SelfContained
)

$ErrorActionPreference = "Stop"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:DOTNET_NOLOGO = "1"

$projectRoot = Split-Path -Parent $PSScriptRoot
$version = "0.0.1-alpha"
$project = Join-Path $projectRoot "windows\XLTD.Vpn.Windows\XLTD.Vpn.Windows.csproj"
$projectDir = Split-Path -Parent $project
$toolsDir = Join-Path $projectDir "tools"
$olcrtcSource = Join-Path $projectRoot ".external\olcrtc"
$olcrtcRepo = if ($env:OLC_REPO) { $env:OLC_REPO } else { "https://github.com/l1ch666/mtsRTC.git" }
$olcrtcRef = if ($env:OLC_REF) { $env:OLC_REF } else { "mtslink-universal-carrier" }
$tun2socksSource = Join-Path $projectRoot ".external\tun2socks"
$ffmpegCacheDir = Join-Path $projectRoot ".external\ffmpeg"
$ffmpegZip = Join-Path $ffmpegCacheDir "ffmpeg-release-essentials.zip"
$ffmpegExtractDir = Join-Path $ffmpegCacheDir "extract"
$ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$wintunCacheDir = Join-Path $projectRoot ".external\wintun"
$wintunZip = Join-Path $wintunCacheDir "wintun-0.14.1.zip"
$wintunExtractDir = Join-Path $wintunCacheDir "extract"
$wintunUrl = "https://www.wintun.net/builds/wintun-0.14.1.zip"
$xrayVersion = if ($env:XRAY_VERSION) { $env:XRAY_VERSION } else { "v26.5.9" }
$xrayCacheDir = Join-Path $projectRoot ".external\xray"
$xrayExtractDir = Join-Path $xrayCacheDir "extract"
$olcrtcPatches = if ($env:OLC_PATCHES) { $env:OLC_PATCHES -split ";" } else { @() }
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

function Resolve-WintunDll {
    if ($env:WINTUN_DLL_PATH -and (Test-Path $env:WINTUN_DLL_PATH)) {
        return (Resolve-Path $env:WINTUN_DLL_PATH).Path
    }

    $arch = switch -Regex ($Runtime) {
        "arm64" { "arm64"; break }
        "x86" { "x86"; break }
        default { "amd64" }
    }

    $knownPaths = @(
        (Join-Path $wintunCacheDir "wintun.dll"),
        (Join-Path $wintunCacheDir "bin\$arch\wintun.dll"),
        (Join-Path $wintunExtractDir "wintun\bin\$arch\wintun.dll"),
        (Join-Path $projectRoot ".external\tun2socks\wintun.dll"),
        (Join-Path $projectDir "tools\wintun.dll")
    )

    foreach ($candidate in $knownPaths) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    New-Item -ItemType Directory -Force -Path $wintunCacheDir | Out-Null
    if (-not (Test-Path $wintunZip)) {
        Write-Host "Downloading Wintun for full tunnel support..."
        Invoke-WebRequest -Uri $wintunUrl -OutFile $wintunZip
    }

    Reset-Directory $wintunExtractDir
    Expand-Archive -LiteralPath $wintunZip -DestinationPath $wintunExtractDir -Force
    $wintun = Get-ChildItem -Path $wintunExtractDir -Recurse -Filter wintun.dll |
        Where-Object { $_.FullName -match "\\bin\\$arch\\wintun\.dll$" } |
        Select-Object -First 1
    if (-not $wintun) {
        $wintun = Get-ChildItem -Path $wintunExtractDir -Recurse -Filter wintun.dll | Select-Object -First 1
    }
    if (-not $wintun) {
        throw "Downloaded Wintun archive did not contain wintun.dll"
    }

    $cached = Join-Path $wintunCacheDir "wintun.dll"
    Copy-Item $wintun.FullName $cached -Force
    return $cached
}

function Resolve-XrayBundle {
    $asset = switch -Regex ($Runtime) {
        "win-x64" { "Xray-windows-64.zip"; break }
        "win-x86" { "Xray-windows-32.zip"; break }
        "win-arm64" { "Xray-windows-arm64-v8a.zip"; break }
        default { throw "Xray alpha packaging currently supports win-x64, win-x86, and win-arm64. Runtime was: $Runtime" }
    }

    $xrayZip = Join-Path $xrayCacheDir "$xrayVersion-$asset"
    $xrayUrl = "https://github.com/XTLS/Xray-core/releases/download/$xrayVersion/$asset"
    New-Item -ItemType Directory -Force -Path $xrayCacheDir | Out-Null
    if (-not (Test-Path $xrayZip)) {
        Write-Host "Downloading Xray-core $xrayVersion ($asset)..."
        Invoke-WebRequest -Uri $xrayUrl -OutFile $xrayZip -UseBasicParsing
    }

    Reset-Directory $xrayExtractDir
    Expand-Archive -LiteralPath $xrayZip -DestinationPath $xrayExtractDir -Force
    $xrayExe = Get-ChildItem -Path $xrayExtractDir -Recurse -Filter xray.exe | Select-Object -First 1
    $geoip = Get-ChildItem -Path $xrayExtractDir -Recurse -Filter geoip.dat | Select-Object -First 1
    $geosite = Get-ChildItem -Path $xrayExtractDir -Recurse -Filter geosite.dat | Select-Object -First 1
    if (-not $xrayExe) {
        throw "Downloaded Xray archive did not contain xray.exe"
    }
    if (-not $geoip -or -not $geosite) {
        throw "Downloaded Xray archive did not contain geoip.dat/geosite.dat"
    }

    return @{
        Xray = $xrayExe.FullName
        Geoip = $geoip.FullName
        Geosite = $geosite.FullName
    }
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

function Ensure-OlcRtcSource {
    if (-not (Test-Path (Join-Path $olcrtcSource ".git"))) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $olcrtcSource) | Out-Null
        Write-Host "Cloning olcRTC ref $olcrtcRef from $olcrtcRepo..."
        & git clone --branch $olcrtcRef --recurse-submodules $olcrtcRepo $olcrtcSource
        if ($LASTEXITCODE -ne 0) {
            throw "git clone olcrtc failed with exit code $LASTEXITCODE"
        }
        return
    }

    Push-Location $olcrtcSource
    try {
        $currentUrl = (& git remote get-url origin 2>$null)
        if ($currentUrl -ne $olcrtcRepo) {
            & git remote set-url origin $olcrtcRepo
            if ($LASTEXITCODE -ne 0) {
                throw "git remote set-url failed with exit code $LASTEXITCODE"
            }
        }

        & git fetch origin $olcrtcRef
        if ($LASTEXITCODE -ne 0) {
            throw "git fetch olcrtc ref $olcrtcRef failed with exit code $LASTEXITCODE"
        }

        & git show-ref --verify --quiet "refs/heads/$olcrtcRef"
        if ($LASTEXITCODE -eq 0) {
            & git checkout $olcrtcRef
        } else {
            & git checkout -b $olcrtcRef "origin/$olcrtcRef"
        }
        if ($LASTEXITCODE -ne 0) {
            throw "git checkout olcrtc ref $olcrtcRef failed with exit code $LASTEXITCODE"
        }

        & git pull --ff-only origin $olcrtcRef
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not fast-forward olcrtc source; using checked out tree as-is."
        }

        & git submodule update --init --recursive
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not update olcrtc submodules; continuing with existing checkout."
        }
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

Ensure-OlcRtcSource

if (-not (Test-Path $tun2socksSource)) {
    throw "Missing local tun2socks source at $tun2socksSource. Rebuild/fetch .external first."
}

foreach ($patch in $olcrtcPatches) {
    Apply-GitPatchIfNeeded $olcrtcSource $patch
}

$ffmpegSource = Resolve-Ffmpeg
$wintunSource = Resolve-WintunDll
$xrayBundle = Resolve-XrayBundle

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
Copy-Item $wintunSource (Join-Path $toolsDir "wintun.dll") -Force
Copy-Item $xrayBundle.Xray (Join-Path $toolsDir "xray.exe") -Force
Copy-Item $xrayBundle.Geoip (Join-Path $toolsDir "geoip.dat") -Force
Copy-Item $xrayBundle.Geosite (Join-Path $toolsDir "geosite.dat") -Force

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
