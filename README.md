# XLTD VPN

Stable Android and Windows VPN clients for olcRTC universal-carrier profiles
and the XLTD-maintained `mtsRTC` MTS Link fork.

Current stable line:

| Platform | Version | Notes |
| --- | --- | --- |
| Android | `1.9.4-universal-carrier` | olcRTC universal-carrier client with MTS Link support. |
| Windows | `0.5.4-beta` | Native Windows GUI with local SOCKS, user proxy, and experimental full tunnel. |

The isolated Xray work lives on branch `alpha/xray-0.0.1` and is versioned as
`0.0.x-alpha`. The stable `main` branch stays focused on olcRTC and MTS Link.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `app/` | Android application. |
| `olcrtcbridge/` | Android bridge module for the native olcRTC runtime. |
| `windows/XLTD.Vpn.Windows/` | Native Windows client. |
| `scripts/` | Android, Windows, olcRTC, packaging, and release helpers. |
| `.external/olcrtc/` | Local checkout/cache of `l1ch666/mtsRTC`, used for bundled olcRTC cores. |

Generated outputs stay out of git: `.tmp/`, `.external/` binaries, `.gradle/`,
`build/`, `app/build/`, `dist/`, and generated `app/libs/*.aar`.

## Supported olcRTC Profiles

```text
olcrtc://<carrier>?<transport><params>@<roomId>#<64_hex_key>$<comment>
```

Accepted transports:

```text
datachannel
vp8channel
seichannel
videochannel
```

Practical defaults:

- `jitsi + datachannel` is the fastest ordinary olcRTC path.
- `telemost + vp8channel` is the main stable Telemost path.
- `mtslink + seichannel` is the recommended MTS Link VPN path.
- `videochannel` remains available for diagnostics and legacy visual transport
  profiles when an ffmpeg-backed core is bundled.

Old links with `%clientId` still parse. Copied server output that contains a
`uri: olcrtc://...` line is accepted too.

## MTS Link

The bundled MTS Link core comes from:

```text
l1ch666/mtsRTC
branch: mtslink-universal-carrier
```

MTS Link joins a public room as a guest and negotiates the H.264/Opus media
shape expected by the service. Normal VPN traffic should use `seichannel`,
which carries data in H.264 SEI payloads. `videochannel` is kept for
diagnostics and legacy visible-video tests.

See [MTSLINK.md](MTSLINK.md) for the server YAML, URI examples, and diagnostics.

## Build

### Android

From Git Bash or a Linux shell:

```bash
bash scripts/build_combo_aar.sh
```

Then build the debug APK:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1
```

The APK is copied to `dist/` and the helper prints a SHA256 hash for release
notes.

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

Output:

```text
dist/windows/XLTD_Vpn-Windows-0.5.4-beta-win-x64.zip
```

The Windows package includes:

- `XLTD_Vpn_Windows.exe`
- `tools/olcrtc.exe`
- `tools/ffmpeg.exe`
- `tools/tun2socks.exe`
- `tools/wintun.dll`
- `tools/data/names`
- `tools/data/surnames`

## Documentation

- [MTSLINK.md](MTSLINK.md) - MTS Link setup and diagnostics.
- [WINDOWS.md](WINDOWS.md) - Windows beta behavior and packaging.
- [CHANGELOG.md](CHANGELOG.md) - release history.
- [MAINTENANCE.md](MAINTENANCE.md) - checks, versioning, publishing, and
  cleanup rules.

## Naming Standard

- Product name: `XLTD VPN`.
- Android artifact prefix: `XLTD_Vpn`.
- Windows executable/package prefix: `XLTD_Vpn_Windows` /
  `XLTD_Vpn-Windows`.
- olcRTC fork repository: `mtsRTC`.
- MTS carrier name in links and configs: `mtslink`.
- Stable Android releases: `v1.9.x`.
- Windows beta releases: `windows-v0.5.x-beta`.
