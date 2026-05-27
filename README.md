# XLTD VPN

Stable Android and Windows VPN clients for olcRTC universal-carrier profiles
and the XLTD-maintained `mtsRTC` MTS Link fork.

Current stable line:

| Platform | Version | Notes |
| --- | --- | --- |
| Android | `1.9.5-universal-carrier` | Dark runtime UI, live telemetry, MTS Link multipath profiles, and rebuilt combo core. |
| Windows | `0.5.5-beta` | Native Windows GUI with local SOCKS, user proxy, experimental full tunnel, and refreshed bundled core. |

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
- `mtslink + seichannel + multipath` is the recommended MTS Link VPN path.
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
which carries data in H.264 SEI payloads. Browser traffic should use
`mc-lanes=12` or a similar 10-16 lane profile so the client can spread SOCKS
streams across several independent MTS Link guest bots. `videochannel` is kept
for diagnostics and legacy visible-video tests.

Android `1.9.5` adds the dark live dashboard from the redesign: status badge,
session traffic counter, transport chips, metrics cards, profile cards with
signal bars, event log, and bottom navigation. The profile storage format is
unchanged.

### What changed in this drop

- **Transport chips are interactive.** Tapping `SEI / VP8 / Data / Video` now
  rewrites the active profile's URI through `rewriteTransport`, persists it,
  and restarts the VPN if it was running. The chips used to be decorative
  (`setClickable(false)`).
- **Pre-tunnel DNS works again.** `OlcVpnService.runVpnOnce` calls
  `olc.setAutoDNS(...)` without try-catch; the matching `SetAutoDNS` /
  `GetAutoDNSUpstream` symbols now exist on the Go side (mtsRTC). Without
  them the VPN crashed on every start with `NoSuchMethodException`.
- **`videochannel` no longer collapses to VP8.** `normalizeTransport` accepts
  `videochannel` and its aliases. `OlcMobileBridge.applyCarrierRuntimeOptions`
  no longer applies the SEI-calibrated `traffic-max-payload` floor to
  videochannel/vp8channel paths (it would have truncated H.264 access units
  in the crypto layer).
- **SEI defaults aligned with the Go runtime.** `OlcVpnService.seiBatch /
  seiFrag / seiAckMs` now default to `8 / 700 / 10000` for every carrier,
  matching `mobile.go`. Previously non-mtslink carriers sent `batch=64,
  ack-ms=2000`, while Go expected `batch=8, ack-ms=10000`.
- **Settings tab is transport-aware.** Fragment/ack/multipath fields are only
  rendered for `seichannel` (and multipath fields only when the carrier is
  `mtslink`), so opening a VP8 profile no longer stamps `mc-lanes=12` into
  the URI on save.
- **Palette extracted into one place.** The dashboard's hex literals now live
  as `COLOR_*` constants in `MainActivity` so retheming is a single-file edit.
- **Traffic tab labelled as approximate.** The metrics come from
  `TrafficStats.getUidRxBytes/TxBytes`, which include the app's own
  background traffic (probes, DNS, HTTP pings), so the panel header now warns
  the user.

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
dist/windows/XLTD_Vpn-Windows-0.5.5-beta-win-x64.zip
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
