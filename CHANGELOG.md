# Changelog

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
