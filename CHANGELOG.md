# Changelog

## 1.6.1-universal-carrier

- Prevented stale delayed autoreconnect threads from starting a worker after the active VPN generation changed.
- Cleared the active link on explicit stop so old reconnect attempts cannot reuse it.
- Updated the user-facing media transport error for `seichannel` and `videochannel`.
- Added a self-contained URI parser contract test and a PowerShell runner.

## 1.6.0-universal-carrier

- Updated the Android client for the olcRTC `refactor/universal-carrier` URI and transport model.
- Switched to a combined gomobile AAR for olcRTC and in-process tun2socks.
- Added support for the new URI format without `%clientId` while keeping the legacy tail format.
