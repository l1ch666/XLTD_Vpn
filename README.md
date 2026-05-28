# XLTD VPN

Stable Android and Windows VPN clients for olcRTC universal-carrier profiles
and the XLTD-maintained `mtsRTC` MTS Link fork.

Current stable line:

| Platform | Version | Notes |
| --- | --- | --- |
| Android | `1.10.0-universal-carrier` | v3 graphite+blue+lime design, live download speed hero, single seichannel (multipath removed). |
| Windows | `0.6.0-beta` | v3 palette, 4-metric home grid, transport chips, rail footer, boot crash fix, multipath removed from YAML. |

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
- `mtslink + seichannel` is the recommended MTS Link VPN path (single channel; multipath was removed as unstable).
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
which carries data in H.264 SEI payloads. Single-channel mode is the only
supported and tested configuration. `videochannel` is kept for diagnostics
and legacy visible-video tests.

Android `1.10.0` brings the v3 graphite-dark + electric-blue + lime design:
download-speed hero (live rate replaces session-bytes counter), lime signal
bars, blue connect gradient, v3 palette throughout. Multipath (mc-lanes etc.)
is removed; SEI runs single-channel.

Windows `0.6.0-beta` mirrors the Android v3 palette, adds 4-metric cards and
transport chips to the home page, adds a live rail footer (SOCKS / Route mode /
Core state), and fixes the blank-UI bug when the boot API calls throw.

### What changed since 1.9.5 / 0.5.5

- **v3 design palette.** Graphite-dark `#0E1014`, electric-blue `#2D7DFF`,
  lime `#C9FF3D`. Hero download-speed arrow is lime. Connect button is blue
  gradient. Signal bars glow lime when active.
- **Single seichannel.** `mc-lanes`, `mc-control-lanes`, `mc-connect-parallel`,
  `mc-min-ready`, `mc-max-streams-per-lane` and the traffic-shaping params are
  removed from all UI, `defaultTransportSpec`, `saveSettings`, and the Windows
  YAML builder. Multipath proved unreliable; single channel is stable.
- **Home speed hero.** The big 46 sp number now shows live download rate
  (Android) / is labelled with the speed value (Windows), not session bytes.
- **Boot crash fix (Windows).** `boot()` is now wrapped in try/catch so a
  failing `api.*` call no longer leaves the renderer blank.
- **Rail footer (Windows).** Shows SOCKS address, current route mode, and core
  running state at all times.

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
dist/windows/XLTD_Vpn-Windows-0.6.0-beta-win-x64.zip
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
- Stable Android releases: `v1.10.x`.
- Windows beta releases: `windows-v0.6.x-beta`.
