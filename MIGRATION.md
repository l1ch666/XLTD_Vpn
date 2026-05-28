# XLTD VPN — Flutter migration (v2.0.0)

Status: **Android — working**. **Windows desktop — code-complete, blocked on
toolchain.**

The Java MainActivity and the Electron renderer are being replaced by a single
Flutter codebase at `flutter_app/`. The Go core (mtsRTC), the Android
`OlcVpnService`, `Tun2SocksMobileBridge`, and the URI parser logic are reused
as-is.

## Project layout

```
flutter_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart              # entry — wires window_manager + AppState
│   ├── theme/                 # v3 palette + ThemeData
│   ├── models/                # OlcConfig, Profile, TelemetrySnapshot, …
│   ├── services/
│   │   ├── uri_parser.dart    # Dart port of OlcUriParser / parser.js
│   │   ├── profiles_store.dart
│   │   ├── formatters.dart
│   │   ├── vpn_bridge.dart    # platform-agnostic interface
│   │   ├── android_vpn_bridge.dart
│   │   └── windows_vpn_bridge.dart
│   ├── state/app_state.dart   # ChangeNotifier wiring everything together
│   ├── widgets/               # HeroStatus, MetricCard, TransportChip, …
│   └── screens/               # Home, Profiles, Traffic, Settings, Log, Shell
├── android/                   # Flutter Android project
│   └── app/
│       ├── build.gradle       # namespace com.s1dechain.olcrtcvpn, min23 / target28
│       ├── libs/              # olcrtccombo.aar (Go core gomobile)
│       └── src/main/
│           ├── AndroidManifest.xml
│           ├── jniLibs/       # native .so files
│           └── java/com/s1dechain/olcrtcvpn/
│               ├── MainActivity.java         # NEW: FlutterActivity + channels
│               ├── OlcVpnService.java        # UNCHANGED + telemetry ticker
│               ├── OlcMobileBridge.java      # UNCHANGED
│               ├── OlcUriParser.java         # UNCHANGED
│               ├── OlcConfig.java            # UNCHANGED
│               ├── Tun2SocksMobileBridge.java
│               └── AndroidVideoRuntime.java
└── windows/                   # Flutter Desktop project (default scaffold)
```

## Method/event channels (Android)

`MainActivity` exposes three channels:

| Channel | Direction | Purpose |
| --- | --- | --- |
| `com.s1dechain.olcrtcvpn/control` | Method | `healthCheck`, `start{uri}`, `stop`, and inbound `deeplink` from intents |
| `com.s1dechain.olcrtcvpn/telemetry` | Event | Snapshot map per status broadcast (state, carrier, transport, rxBps/txBps, sessionRx/Tx, latencyMs, uptimeMs) |
| `com.s1dechain.olcrtcvpn/log` | Event | One line per VPN event tagged OK/DNS/TUN/HINT/ERR/LOG |

`AndroidVpnBridge` (Dart) consumes them, decodes into `TelemetrySnapshot` and
`LogEvent`, and re-emits as streams that the UI listens to.

## Windows bridge

`WindowsVpnBridge` (Dart) spawns `olcrtc.exe`, writes a YAML config to
`%APPDATA%\XLTD_Vpn\runtime\client.yaml`, polls a SOCKS5 handshake to detect
readiness, and tails stdout/stderr into the log stream. This is a one-to-one
port of `windows/electron-app/services/core.js`.

The toolchain ships in `flutter_app/windows/runner/` (default Flutter desktop
scaffold). `olcrtc.exe`, `tun2socks.exe`, `wintun.dll`, `ffmpeg.exe` go into the
`tools/` directory next to the built `xltd_vpn.exe` (same layout the Electron
build used).

## Profile migration

`UriParser.stripLegacyMultipath()` removes `mc-*` and `traffic-*` parameters
from saved profile URIs on first load. Pre-1.10 profiles continue to parse and
connect, but no longer advertise multipath knobs.

## Telemetry ticker (Android)

`OlcVpnService` now starts a 1.5 s `HandlerThread` ticker on `tunEstablished
= true`. Each tick re-broadcasts `ACTION_STATUS` so the Flutter UI sees live
speed / uptime updates instead of waiting for the next state transition. The
baseline (`trafficBaseRx/Tx`) is reset at the same moment so the first measured
byte is post-tunnel. Ticker is cancelled on disconnect and on every controlled
reconnect.

Fixes the user-reported "stats не обновляются первые 7–15 секунд" issue.

## Build

### Android (working)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1 -Mode debug
# or -Mode release
```

The result lands in `dist/XLTD_Vpn-2.0.0-flutter-<mode>.apk`. First build is
slow (~5 min — Gradle downloads its full plugin cache); subsequent builds
take ~30 s.

### Windows (blocked on toolchain)

```powershell
flutter build windows --debug
```

Currently fails with:

```
CMake Error at CMakeLists.txt:3 (project):
  Generator
    Visual Studio 16 2019
  could not find any instance of Visual Studio.
```

The local box has Visual Studio Build Tools **2026** (preview). Flutter 3.24.5
only knows about VS 2019 (`gen=16`) and VS 2022 (`gen=17`). Options:

1. **Recommended:** install Visual Studio Community/Professional **2022** with
   the *Desktop development with C++* workload — Flutter detects it
   automatically.
2. Upgrade Flutter to a 3.27+ build that supports newer generators.

Once VS 2022 is on the box, `flutter build windows --release` will emit
`flutter_app\build\windows\x64\runner\Release\xltd_vpn.exe`. A future
`scripts\build_windows.ps1` rewrite will copy `tools/` next to it and zip.

## Known gaps before v2.0.0 release

| Area | Status | Notes |
| --- | --- | --- |
| Android APK builds | ✅ Working | Verified `flutter build apk --debug` |
| Android live telemetry ticker | ✅ Fixed | 1.5 s `HandlerThread` |
| Profile migration (drop `mc-*`) | ✅ | `stripLegacyMultipath()` |
| URI parser feature parity | ✅ | covered by smoke test |
| Windows desktop builds | ❌ Blocked | install VS 2022 |
| Windows full tunnel (Wintun + tun2socks) | ✅ Code-complete | `WindowsRouteService` — spawn tun2socks, add host-route exclusions for VPN server + DNS, set Wintun-adapter DNS, restore on stop |
| Windows DNS leak fix | ✅ Code-complete | DNS upstream is added as an excluded host-route and locked on the Wintun adapter so OS resolvers stay through the tunnel |
| Reconnect-storm verbose logging | ⚠ Pending | needs liveness ping/pong trace |
| `flutter run` hot reload on Windows | ⚠ Blocked | Developer Mode disabled (needs admin) |

## Developer Mode (Windows)

Plugin builds use symlinks. To enable hot reload:

```
Settings > Privacy & security > For developers > Developer Mode > ON
```

Without it, `flutter run` fails with `Building with plugins requires symlink
support.`. `flutter build` still works.
