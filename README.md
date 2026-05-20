# XLTD VPN alpha / olcRTC Android client

This branch is the isolated `0.0.1-alpha` line for a large Xray backend update.
Stable olcRTC/MTS Link behavior is kept on the main line; the alpha branch adds
Xray as a parallel backend for Android and Windows.

This build uses the `l1ch666/mtsRTC` `mtslink-universal-carrier` fork for the bundled olcRTC core.

Main point: the old app was mostly `datachannel/vp8channel`-only and expected the older URI layout with `%clientId`. The universal-carrier branch changes carrier/transport compatibility and the client URI docs no longer require `%clientId`, so the Android parser and combo AAR builder were updated.

## Windows alpha

The repository also contains a separate Windows client:

```text
windows/XLTD.Vpn.Windows
```

Windows uses its own version line. Current Windows alpha on this branch: `0.0.1-alpha`. Build it with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

See `WINDOWS.md` for the Windows alpha scope and release policy.

## Xray alpha

The alpha clients also accept Xray profiles:

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

The Android and Windows clients generate a local SOCKS inbound on
`127.0.0.1:10808`, then reuse the existing VPN/proxy plumbing. Xray-core is
pinned to `v26.5.9` in the build scripts. See `XRAY_ALPHA.md` for the exact
build commands, supported stream settings, and alpha limitations.

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
- `seichannel` is accepted and passed into the new Android core. MTS Link now uses slower defaults for bursty H.264/SEI traffic.
- `videochannel` can run on Android when the combo AAR is built with the bundled Android ffmpeg asset, or when a profile supplies `android-ffmpeg=<path>`.
- `mtslink` is a local olcRTC fork carrier that uses `seichannel` over H.264/SEI. See `MTSLINK.md`.

## URI support

Both Android and Windows accept either a raw `olcrtc://...` link or a copied
server output block that contains a `uri: olcrtc://...` line.

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

For `vp8channel`, the bundled core now probes both binding schemes during
startup: legacy `%clientId` / `-client-id` and the newer room-based token. It
pins to the first valid peer token it receives, which keeps compatibility while
avoiding duplicate traffic after the peer is detected.

Telemost room ids are also normalized both ways for VP8 binding: a peer using
`25000437143020` and a peer using
`https://telemost.yandex.ru/j/25000437143020` will accept each other.

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

For MTS Link, use the safer default profile:

```text
fps=30
batch=8
frag=700
ack-ms=10000
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

Android videochannel runtime uses a separate ffmpeg-backed native binary. The
default combo-AAR build downloads an Android ffmpeg asset for `arm64-v8a` and
stores it under `assets/ffmpeg/<abi>/ffmpeg`. You can override the runtime path
in a profile with:

```text
android-ffmpeg=/data/local/tmp/ffmpeg
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

## What changed in 1.9.4

- Raised MTS Link traffic payload handling from the old 1200-byte cap to a dynamic `frag * 8` floor, so larger SEI frames and old saved profiles do not kill the control stream.
- Windows full tunnel now routes DNS servers outside the TUN adapter and shortens UDP sessions, reducing UDP-over-SOCKS5 failure storms when the olcRTC SOCKS endpoint is TCP-only.
- Windows `0.5.4-beta` carries the same MTS Link payload and full-tunnel fixes.

## What changed in 1.9.3

- Patched `l1ch666/mtsRTC` directly on `mtslink-universal-carrier` instead of rebasing the MTS core onto newer upstream olcRTC.
- Switched Android and Windows build scripts to use `mtsRTC` by default, so rebuilt cores come from the patched fork as-is.
- Rebuilt Android and Windows artifacts from the fixed fork.
- Windows `0.5.3-beta` carries the same corrected core source selection.

## What changed in 1.9.2

- Rebased the local MTS Link olcRTC patch on the latest `refactor/universal-carrier` core.
- Reworked `seichannel` reliability to ACK individual fragments instead of retrying whole visual messages under loss.
- Added MTS Link liveness and traffic-shaping defaults for slower H.264/SEI rooms: 30 FPS, batch 8, 700-byte fragments, 10s ACK timeout.
- Android now prepares an ffmpeg-backed video runtime for `videochannel` from bundled assets or an explicit `android-ffmpeg` path.
- Windows `0.5.2-beta` packages `wintun.dll` with `tun2socks.exe` for full tunnel mode.

## What changed in 1.9.1

- Fixed the MTS Link H.264 path used by `videochannel`: outgoing QR video now uses a separate sendonly m-line and keeps an incoming video receiver for the peer tunnel.
- Fixed raw H.264 frame boundaries from ffmpeg so WebRTC receives complete Annex-B access units, not arbitrary pipe chunks.
- Windows `0.5.1-beta` targets the post-join `open control stream` timeout seen after MTS SFU connected successfully.

## What changed in 1.9.0

- Reworked the local `mtslink` carrier patch from the reviewed visible-H.264 fork.
- Hardened the MTS Link guest bot flow: prejoin cookies, guestlogin, connection/conference creation, join-token extraction, peer update, pinning, and silent Opus keepalive.
- Added runtime knobs for MTS diagnostics: `mts-video-test`, `mts-video-codec`, `mts-peer-update`, `mts-silent-audio`, and `mts-force-video`.
- Windows `0.5.0-beta` is the runnable MTS Link target; Android keeps parser/profile support until an ffmpeg-backed Android core is packaged.

## What changed in 1.8.0

- Added an experimental local olcRTC fork patch for `mtslink` carrier support.
- MTS Link joins public rooms as a guest and uses H.264 WebRTC media with olcRTC `videochannel`.
- Permanent MTS Link `/j/{userId}/{eventId}` links resolve the active session automatically.
- Added parser coverage for percent-encoded MTS Link room URLs.
- Added `MTSLINK.md` with a standard YAML server setup and matching client URI.

## What changed in 1.7.0

- Fixed a VP8/KCP startup timeout where Android, Windows, or server YAML could hash different Telemost room forms (`roomId` vs full Telemost URL).
- Kept legacy `%clientId` compatibility while adding Telemost room-id/full-URL fallback tokens.
- Updated the combo AAR generator so Android passes Telemost room ids in the same raw form as Windows/server configs.
- Windows beta 0.3.0 now packages `ffmpeg.exe`, so `videochannel` no longer exits with `new encoder: ffmpeg is required for videochannel`.
- Android now reports a clear runtime error for `videochannel` until an ffmpeg-backed Android core is packaged.

## What changed in 1.6.4

- Fixed VP8 channel startup against legacy `%clientId` / `-client-id` generated links while keeping compatibility with newer universal-carrier room binding.
- Allowed parser input copied from server output blocks such as `uri: olcrtc://...`.
- Added regression coverage for the server-output URI format and VP8 binding-token fallback.

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

- `scripts/build_combo_aar.sh` now targets the configured olcRTC fork/ref by default.
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
OLC_REPO=https://github.com/l1ch666/mtsRTC.git
OLC_REF=mtslink-universal-carrier
```

By default it also downloads Android ffmpeg `8.1` for `arm64-v8a`. Use
`ANDROID_FFMPEG_ABIS=arm64-v8a,armeabi-v7a` to bundle more ABIs,
`ANDROID_FFMPEG_DIR=/path/to/ffmpeg-assets` to use local binaries, or
`ANDROID_FFMPEG=0` to build without the video runtime asset.

Override only if you know what you are testing:

```bash
OLC_REPO=https://github.com/openlibrecommunity/olcrtc.git OLC_REF=master OLC_PATCHES="$PWD/patches/olcrtc-mtslink-carrier.patch" bash scripts/build_combo_aar.sh
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
