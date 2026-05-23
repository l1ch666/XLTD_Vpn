# XLTD VPN

Android and Windows VPN clients for olcRTC carriers, the MTS Link olcRTC fork,
and the isolated Xray alpha backend.

This repository keeps two product lines clear:

| Line | Branch | Current version | Notes |
| --- | --- | --- | --- |
| Stable olcRTC client | `main` | Android `1.9.x`, Windows `0.5.x-beta` | Existing olcRTC/MTS Link work. |
| Xray alpha | `alpha/xray-0.0.1` | Android/Windows `0.0.3-alpha` | Parallel Xray backend without replacing olcRTC. |

The alpha branch still accepts normal `olcrtc://` profiles. Xray profiles run
through a separate local SOCKS backend on `127.0.0.1:10808`.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `app/` | Android application. |
| `olcrtcbridge/` | Android bridge module for olcRTC and Xray runtimes. |
| `windows/XLTD.Vpn.Windows/` | Native Windows client. |
| `scripts/` | Android, Windows, olcRTC, Xray, and release build helpers. |
| `.external/olcrtc/` | Local checkout of `l1ch666/mtsRTC`, used for bundled olcRTC cores. |
| `.external/xray-core/`, `.external/tun2socks/` | Build caches/source checkouts used by scripts. |

Generated outputs stay out of git: `.tmp/`, `.external/` binaries, `.gradle/`,
`build/`, `app/build/`, `dist/`, and generated `app/libs/*.aar`.

## Supported Profiles

### olcRTC

```text
olcrtc://<carrier>?<transport><params>@<roomId>#<64_hex_key>$<comment>
```

Accepted carriers and transports depend on the server side:

- `telemost + vp8channel` is the main stable Telemost profile.
- `jitsi + datachannel` is the fastest ordinary olcRTC profile.
- `mtslink + seichannel` is the recommended MTS Link VPN profile.
- `videochannel` remains available for diagnostics and legacy visual transport
  profiles when an ffmpeg-backed core is bundled.

Old olcRTC links with `%clientId` still parse, and copied server output that
contains `uri: olcrtc://...` is accepted.

MTS Link details live in [MTSLINK.md](MTSLINK.md).

### Xray Alpha

The alpha parser accepts:

```text
vless://...
vmess://...
trojan://...
ss://...
socks://...
http-proxy://...
xray://<base64url-or-url-encoded-json>
{ raw Xray JSON config }
```

Supported stream settings include TLS, Reality, TCP, WebSocket, gRPC, HTTP/H2,
XHTTP/SplitHTTP, KCP, and QUIC profile parameters. See
[XRAY_ALPHA.md](XRAY_ALPHA.md).

## Build

### Android

```powershell
& 'C:\Program Files\Git\bin\bash.exe' scripts/build_combo_aar.sh
powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1
```

The combo AAR build prepares the native olcRTC runtime, Android ffmpeg assets
for media transports, and Android Xray assets for the alpha backend.

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

Output:

```text
dist/windows/XLTD_Vpn-Windows-0.0.3-alpha-win-x64.zip
```

The Windows package includes `olcrtc.exe`, `xray.exe`, `ffmpeg.exe`,
`tun2socks.exe`, `wintun.dll`, `geoip.dat`, and `geosite.dat`.

## Documentation

- [MTSLINK.md](MTSLINK.md) - MTS Link server/client setup and diagnostics.
- [XRAY_ALPHA.md](XRAY_ALPHA.md) - Xray alpha scope, accepted links, and build
  notes.
- [WINDOWS.md](WINDOWS.md) - Windows client behavior and package contents.
- [CHANGELOG.md](CHANGELOG.md) - release history.
- [MAINTENANCE.md](MAINTENANCE.md) - local checks, release policy, and cleanup
  rules.

## Naming Standard

- Product name: `XLTD VPN`.
- Android package artifact prefix: `XLTD_Vpn`.
- Windows executable/package prefix: `XLTD_Vpn_Windows` /
  `XLTD_Vpn-Windows`.
- olcRTC fork repository: `mtsRTC`.
- MTS carrier name in links and configs: `mtslink`.
- Xray alpha releases: `xltd_xray_alpha_<version>`.
