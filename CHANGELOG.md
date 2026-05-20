# Changelog

## 1.9.3-universal-carrier

- Switched Android core builds to `l1ch666/mtsRTC` `mtslink-universal-carrier` instead of applying the MTS patch onto fresh upstream.
- Rebuilt the combo AAR from the patched fork where `seichannel` ACKs individual fragments and uses safer MTS Link defaults.

## Windows 0.5.3-beta

- Switched Windows `olcrtc.exe` builds to `l1ch666/mtsRTC` `mtslink-universal-carrier`.
- Rebuilt the Windows package from the patched fork without rebasing the core on newer upstream olcRTC.

## 1.9.2-universal-carrier

- Rebased the local MTS Link olcRTC fork patch on the latest `refactor/universal-carrier` core.
- Reworked `seichannel` ACK handling to acknowledge individual fragments, reducing whole-message retries and control-stream liveness drops on lossy visual media.
- Added MTS Link SEI defaults for bursty rooms: 30 FPS, batch 8, 700-byte fragments, and 10s ACK timeout.
- Added Android `videochannel` runtime support: the combo AAR can bundle Android ffmpeg assets and the VPN service passes the extracted ffmpeg path into the native core.

## Windows 0.5.2-beta

- Bundled `wintun.dll` with the Windows package so full tunnel mode can create the Wintun adapter next to `tun2socks.exe`.
- Added clearer full-tunnel preflight errors when Wintun is missing or `tun2socks` exits before adapter creation.
- Added MTS Link liveness and traffic-shaping defaults for `seichannel` profiles, while keeping URI parameters overrideable.

## 1.9.1-universal-carrier

- Fixed MTS Link videochannel negotiation so the incoming video receiver stays separate from the outgoing H.264 QR track.
- Fixed H.264 encoder framing: ffmpeg output is now split into complete Annex-B access units before `WriteSample`, instead of arbitrary pipe chunks.
- Forced low-latency baseline H.264 encoder settings with repeated headers for MTS Link compatibility.

## Windows 0.5.1-beta

- Rebuilt Windows with the MTS Link video transceiver and H.264 frame-boundary fixes.
- This specifically targets the `open control stream: timeout/read-write on closed pipe` failure after a successful MTS SFU join.

## 1.9.0-universal-carrier

- Replaced the first experimental MTS Link patch with the reviewed fork implementation from `olcrtc-mtslink-universal-carrier-visible-h264-compilefix-fork.zip`.
- Hardened MTS Link guest bot bootstrap: prejoin page cookies, guestlogin, cached session probes, connection/conference creation, join-token extraction, and publish-token fallback.
- Added MTS Link peer update flow, visible H.264 diagnostic frames, explicit H.264 codec profile, repeated pinning, and silent Opus RTP to make the bot look closer to a browser participant.
- Kept Android parser/profile support and MTS Link video defaults while Android runtime `videochannel` remains blocked until an ffmpeg-backed Android core is packaged.

## Windows 0.5.0-beta

- Rebuilt Windows with the reviewed MTS Link fork core.
- Added MTS runtime environment wiring for `MTS_FORCE_VIDEO`, `MTS_PEER_UPDATE`, `MTS_SILENT_AUDIO`, optional `MTS_VIDEO_TEST`, and optional `MTS_VIDEO_CODEC`.
- Kept Windows as the runnable MTS Link target with bundled `ffmpeg.exe`, `olcrtc.exe`, and `tun2socks.exe`.

## 1.8.0-universal-carrier

- Added a local olcRTC fork patch for experimental `mtslink` carrier support.
- Added MTS Link guest bootstrap, `/stream-new/{sessionId}` room handling, and an H.264 WebRTC engine for `videochannel`.
- Added lazy session discovery for permanent MTS Link `/j/{userId}/{eventId}` room links.
- Added MTS Link URI/parser coverage and a `MTSLINK.md` noobs server/client setup guide.
- Android can parse and store MTS Link profiles, but runtime `videochannel` still requires an ffmpeg-backed Android core.

## Windows 0.4.0-beta

- Rebuilt Windows with the local MTS Link olcRTC fork patch.
- Added Windows defaults for `mtslink` `videochannel`: 640x360, 15 FPS, 1200k bitrate.
- Windows remains the runnable client target for MTS Link because the package already bundles `ffmpeg.exe`.

## 1.7.0-universal-carrier

- Fixed `vp8channel` startup when one side hashes a bare Telemost room id and the other side hashes the canonical `https://telemost.yandex.ru/j/...` URL.
- Kept the legacy `%clientId` / `-client-id` binding compatibility from 1.6.4 and added Telemost room-id/full-URL regression coverage.
- Updated the Android combo bridge so Telemost room ids are passed to olcRTC in the same raw form as Windows/server YAML.
- Added explicit Android runtime diagnostics for `videochannel`: URI parsing remains universal-carrier compatible, but this APK requires an ffmpeg-backed Android core for videochannel runtime.

## Windows 0.3.0-beta

- Rebuilt the bundled Windows core with the same Telemost bare-id/full-URL `vp8channel` binding compatibility.
- Bundled `ffmpeg.exe` in the Windows package so `videochannel` can start instead of exiting with `new encoder: ffmpeg is required for videochannel`.
- Hardened Windows/Android build helpers so an already-applied local olcRTC patch is detected even when the external checkout has Windows line endings.

## 1.6.4-universal-carrier

- Fixed VP8 channel compatibility with legacy `%clientId` / `-client-id` links while keeping the newer room-URL binding fallback.
- Allowed Android URI parsing from copied server output blocks that contain a prefixed `uri: olcrtc://...` line.
- Added parser and VP8 binding-token regression coverage for legacy and universal-carrier links.

## Windows 0.2.1-beta

- Fixed Windows profile list painting so selected rows no longer show the system blue background.
- Polished editor buttons to match the softer secondary-button style and avoid clipped pill bottoms.
- Reduced noisy core trace logs in the GUI and disabled verbose core debug mode by default.
- Improved startup status handling when `olcrtc.exe` exits before the local SOCKS listener is ready.
- Fixed Windows URI parsing from copied server output and rebuilt the bundled core with the same VP8 legacy/new binding-token compatibility as Android.

## Windows 0.2.0-beta

- Restyled the Windows client with softer rounded cards, pill buttons, and a black/white visual direction closer to the Android app.
- Added an experimental full tunnel mode using bundled `tun2socks.exe` and a Wintun-backed TUN adapter.
- Added route/DNS setup and rollback for the Windows full tunnel mode.
- Updated the Windows package to include both `olcrtc.exe` and `tun2socks.exe`.

## Windows 0.1.0-beta

- Added the first native Windows beta client under `windows/XLTD.Vpn.Windows`.
- Added the Windows `olcrtc://` URI parser, local profile storage, local SOCKS startup, and optional Windows user proxy mode.
- Added `scripts/build_windows.ps1` to build `olcrtc.exe`, publish the GUI, package a zip, and print SHA256.
- Added `WINDOWS.md` with the Windows beta scope and versioning policy.

## 1.6.3-universal-carrier

- Registered the runtime status receiver as not exported on Android 13+.
- Restored the latest service status when the activity is recreated or reopened.
- Added a notification content intent so tapping the foreground VPN notification opens the app.
- Printed SHA256 from the APK build helper for release verification.

## 1.6.2-universal-carrier

- Guarded controlled reconnect threads with the active worker generation before shutdown/start handoff.
- Added `scripts/build_apk.ps1` to build the APK with Android Studio JBR and cached Gradle.
- Updated `scripts/build_combo_aar.sh` for the current universal-carrier `client.Config` API and typed transport options.
- Moved native-library extraction behavior from the manifest to Gradle packaging options and set Java 11 compile options.
- Ignored generated release artifacts under `dist/` and generated local AAR/source artifacts under `app/libs/`.

## 1.6.1-universal-carrier

- Prevented stale delayed autoreconnect threads from starting a worker after the active VPN generation changed.
- Cleared the active link on explicit stop so old reconnect attempts cannot reuse it.
- Updated the user-facing media transport error for `seichannel` and `videochannel`.
- Added a self-contained URI parser contract test and a PowerShell runner.

## 1.6.0-universal-carrier

- Updated the Android client for the olcRTC `refactor/universal-carrier` URI and transport model.
- Switched to a combined gomobile AAR for olcRTC and in-process tun2socks.
- Added support for the new URI format without `%clientId` while keeping the legacy tail format.
