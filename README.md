# olcRTC Android client — 1.6.3 universal-carrier

This build updates the Android client for the `openlibrecommunity/olcrtc` `refactor/universal-carrier` branch.

Main point: the old app was mostly `datachannel/vp8channel`-only and expected the older URI layout with `%clientId`. The universal-carrier branch changes carrier/transport compatibility and the client URI docs no longer require `%clientId`, so the Android parser and combo AAR builder were updated.

## Accepted transports

```text
datachannel
vp8channel
seichannel
videochannel
```

Reality check for Android VPN mode:

- `datachannel` is still the fastest when the carrier supports it.
- `vp8channel` is the main stable media transport for `telemost` / `wbstream`.
- `seichannel` and `videochannel` are accepted and passed into the new core, but they are still more experimental on Android because they are media/video-based and can be slower or more fragile under full-TUN traffic bursts.

## URI support

### New universal-carrier style

No `%clientId` is required. Android defaults `clientId` to `default` unless you put `client-id=...` in transport params.

```text
olcrtc://<carrier>?<transport><params>@<roomId>#<64_hex_key>$<comment>
```

Example:

```text
olcrtc://telemost?vp8channel<vp8-fps=60&vp8-batch=64>@25000437143020#81a715aad4224c9179bd36c6725a9375b65d85161f81c12ab20dc23cb276a71b$telemost-vp8
```

### Old style still supported

The old format with `%clientId` still parses:

```text
olcrtc://telemost?vp8channel<vp8-fps=30&vp8-batch=4>@25000437143020#81a715aad4224c9179bd36c6725a9375b65d85161f81c12ab20dc23cb276a71b%default$direct
```

## Transport params

### VP8

```text
vp8-fps=60
vp8-batch=64
```

Aliases also work: `fps`, `batch`.

### SEI

```text
fps=60
batch=64
frag=900
ack-ms=2000
```

### Video

```text
video-codec=qrcode
video-w=1080
video-h=1080
video-fps=60
video-bitrate=5000k
video-hw=none
video-qr-size=0
video-qr-recovery=low
video-tile-module=4
video-tile-rs=20
```

### Android-only VPN params

These are not olcRTC core params, they tune the Android full-VPN wrapper:

```text
mtu=<900..1500>
tcp-limit=<1..32>
link=direct
client-id=<id>
```

Example:

```text
olcrtc://wbstream?vp8channel<vp8-fps=60&vp8-batch=64&tcp-limit=2&mtu=1040&client-id=default>@019e1742-db64-733a-a991-a570984bdb59#bbb9a2e3613bd4dc93fc88f858e0a4a882b30b55976cb6f408e1f421a9cda9c4$wb-vp8
```

## What changed in 1.6.3

- Registered the in-app status receiver with `RECEIVER_NOT_EXPORTED` on Android 13+ for cleaner compatibility with newer platform rules.
- Added an in-process last-status snapshot so reopening or rotating the app restores the latest VPN status instead of falling back to a disconnected-looking UI.
- Added a notification tap action that returns to the main VPN screen.
- `scripts/build_apk.ps1` now prints the APK SHA256 hash used in GitHub release notes.

## What changed in 1.6.2

- Hardened controlled reconnects for network/core storm events: stale reconnect threads now check the worker generation before shutting resources down or starting a new worker.
- Updated combo AAR generation for the current universal-carrier Go API, where `client.RunWithReady` now receives `client.Config`.
- Added a local APK build helper that uses the Android Studio JBR and cached Gradle when plain `gradle` is not on `PATH`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1
```

The helper copies the generated APK to `dist/XLTD_Vpn-<version>-debug.apk` for GitHub releases.

## What changed in 1.6.1

- Fixed a stale delayed reconnect race: an old autoreconnect timer no longer restarts the worker after a newer manual start/stop changed the active generation.
- Fixed the UI error text for `seichannel` / `videochannel`: these transports are accepted in universal-carrier builds; missing support now points to rebuilding the combo AAR instead of claiming they are unsupported.
- Added a lightweight parser contract test that runs without Gradle/JUnit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_parser_contract_test.ps1
```

## What changed in 1.6.0

- `scripts/build_combo_aar.sh` now targets `refactor/universal-carrier` by default.
- Combo AAR glue now passes the new `engine/url/token` tail args used by the universal-carrier client path.
- Combo AAR glue applies `session.ApplyAuthDefaults(...)` before starting the client.
- Parser accepts the new no-`%clientId` URI and defaults to `clientId=default`.
- Parser keeps backward compatibility with old `%clientId` links.
- Android parser no longer rejects `seichannel` and `videochannel`.
- Java bridge now calls `SetSEIOptions(...)` and `SetVideoOptions(...)` when the combo AAR exposes them.
- `seichannel` and `videochannel` are no longer force-downgraded to `datachannel` inside the generated combo bridge.
- Visual/media transports use the safer Android settings path: lower MTU fallback, lower TCP burst limiter, stabilization delay, and longer remote CONNECT warmup.
- Version bumped to `1.6.0-universal-carrier`.

## Build

From Git Bash / Linux shell in the project folder:

```bash
bash scripts/build_combo_aar.sh
```

The script uses:

```bash
OLC_REF=refactor/universal-carrier
```

Override only if you know what you are testing:

```bash
OLC_REF=master bash scripts/build_combo_aar.sh
```

Then build APK in Android Studio:

```text
Build → Generate App Bundles or APKs → Generate APK(s)
```

or with Gradle:

```bash
gradle clean :app:assembleDebug
```

Install:

```bash
adb uninstall com.s1dechain.olcrtcvpn
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Expected good log pattern

```text
Parsed config: carrier=telemost
transport=vp8channel
clientId=default
STATUS: Ссылка разобрана: telemost / vp8channel <vp8-fps=60, vp8-batch=64> / MTU 1040
STATUS: Подключаю olcRTC vp8channel...
SOCKS5 server listening on 127.0.0.1:10808
STATUS: Жду стабилизацию RTC media-канала 3.5 сек...
STATUS: Проверяю, что серверная сторона olcRTC уже отвечает на CONNECT...
STATUS: Remote CONNECT OK через olcRTC: 1.1.1.1:443
STATUS: VPN connected
Transport: vp8channel <vp8-fps=60, vp8-batch=64>
TCP start limiter: 2 parallel dials
```

Bad signs are repeated `remote not ready`, `CONNECT: host unreachable`, mass `client link reconnect`, or failure before `SOCKS5 server listening`.
