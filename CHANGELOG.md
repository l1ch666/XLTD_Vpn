# Changelog

## Unreleased — v3 Design / Single SEI channel

### Android 1.10.0

- **v3 palette applied.** All colours migrated to the v3 graphite-dark + electric-blue
  (`#2D7DFF`) + lime (`#C9FF3D`) design system. Background `#0E1014`, surface
  `#181B22`, border `#262A33`; SEI/OK signal is now lime, connect button is a blue
  gradient `#4F8BFF → #1A5FE0`, signal bars glow lime when active.
- **Hero shows download speed.** The home screen hero now displays the live
  download rate (e.g. `12.4 MB/s`) as the primary 46 sp metric with a lime `↓`
  arrow, replacing the session-bytes counter. Session total is shown as a smaller
  sub-label.
- **Single seichannel — multipath removed.** All `mc-lanes`, `mc-control-lanes`,
  `mc-connect-parallel`, `mc-min-ready`, `mc-max-streams-per-lane` settings and
  their corresponding `traffic-max-payload / min-delay / max-delay` shaping params
  are gone from the Settings tab, `saveSettings()`, and `defaultTransportSpec()`.
  New SEI profiles no longer carry `mc-lanes=12`. Existing saved profiles with those
  params continue to parse and connect — they just won't be shown or re-injected.
- **`activeTransportLabel()` simplified.** The label now returns `"SEI"` for
  seichannel instead of `"SEI · N lanes"`. `profileMeta()` for SEI no longer shows
  `lanes=N`.
- **Nav items use muted text for inactive state** instead of the nearly-invisible
  border-grey.
- **`telemetryLanes` field retained** (read from broadcast) but no longer surfaced
  anywhere in the UI. The `txDelta` metric label always reads `"один канал"`.
- **Bug fix — boot try/catch (Android).** `onStart()` calls `renderActiveTab()`
  which could crash if any view reference was stale after a configuration change.
  The `renderActiveTab()` null-guards remain; no regression introduced.

### Windows 0.6.0-beta

- **v3 palette applied.** CSS `:root` variables updated — primary `#2D7DFF`, ok/lime
  `#C9FF3D`, bg `#0E1014`, surface `#181B22`, border `#262A33`. `main.js`
  `backgroundColor` updated to match.
- **Home page `Канал жив.`** page head added above the hero. Transport chips row
  added below the status hero. 4-metric grid (↓/↑/latency/uptime) now rendered on
  the Home tab, not only on Traffic.
- **Lime `↓` arrow** in the hero speed display (`color:var(--ok)`).
- **Rail footer** now shows SOCKS address + Route mode + Core state (stopped /
  connecting / connected). The title-bar center label updates to the active carrier
  name when connected.
- **`boot()` wrapped in try/catch.** If any `await api.*` call fails on startup the
  UI still renders with defaults instead of staying blank.
- **Single seichannel — multipath removed from YAML builder.** The `multipath:`
  section (`lanes`, `control_lanes`, `connect_parallelism`, `min_ready`,
  `max_streams_per_lane`) and the `traffic:` shaping block are no longer emitted for
  any config. `buildYaml()` in `services/core.js` is ~25 lines shorter.
- **`updateRailFooter()`** keeps the rail in sync after every connect/disconnect and
  tab switch without a full page re-render.
- **Sparkline bars** use lime gradient (`--ok → #8FCC00`) when active.

- **VPN bootstrap restored.** `OlcVpnService.runVpnOnce` calls
  `olc.setAutoDNS(...)` to pick a pre-tunnel DNS upstream; the matching
  `SetAutoDNS` / `GetAutoDNSUpstream` symbols now exist in the bundled `mtsRTC`
  mobile API, so the service no longer crashes with `NoSuchMethodException` on
  every connect attempt.
- **Transport chips are interactive.** Tapping `SEI / VP8 / Data / Video`
  rewrites the active profile's URI via `switchSelectedTransport` and restarts
  the VPN if it was running. Chips were previously decorative.
- **`videochannel` recognised end-to-end.** `mtsRTC`'s `normalizeTransport`
  no longer collapses `videochannel` to `vp8channel`. The Android
  `OlcMobileBridge` also stops applying the SEI-calibrated `traffic-max-payload`
  floor to `videochannel`/`vp8channel`, which would have truncated H.264
  access units at the crypto layer.
- **SEI defaults aligned with the Go runtime.** Java `seiBatch / seiFrag /
  seiAckMs` defaults are now `8 / 700 / 10000` for every carrier (mtslink and
  others) so Android and Go agree on batch sizes and ACK timeouts. Non-mtslink
  carriers previously sent `batch=64, ack-ms=2000` against Go's `8 / 10000`.
- **Per-transport probe options.** `mtsRTC` `Check()` and `Ping()` build
  `TransportOptions` via `buildCheckOptions`, so SEI probes get
  `seichannel.Options`, video probes pass `nil`, and VP8/data still get
  `vp8channel.Options`. The hard-coded `vp8channel.Options` against SEI used
  to fail with `ErrOptionsTypeMismatch`.
- **Settings tab is transport-aware.** `buildSettingsForm` only renders SEI
  fields when the active transport is SEI, and only renders multipath fields
  when the carrier is mtslink. Opening a VP8 profile no longer stamps
  `mc-lanes=12` into the URI on save.
- **Palette extracted.** Dashboard hex literals moved into `COLOR_*` static
  finals in `MainActivity` so retheming is a single-file edit.
- **Traffic tab labelled as approximate.** The metrics are sourced from
  `TrafficStats.getUidRxBytes/TxBytes`, which include the app's own
  background traffic; the tab header now warns the user.
- **Tighter reconnect locking.** `OlcVpnService.scheduleReconnectIfNeeded`
  captures the `workerGeneration` under the same monitor that mutates it,
  closing a TOCTOU window where a controlled reconnect could race the delayed
  reconnect thread.
- **mtsRTC transport hardening.** The `seichannel` remote-track goroutine
  now checks the closed flag and `closeCh` at the top of every read loop and
  reads with a 250 ms deadline, bounding goroutine lifetime under reconnect
  storms. The MTS Link engine threads a cancellable context through the silent
  audio pump and the pin loop, and bounds `Pin()` calls with a 5 s deadline so
  `Close()` cannot strand a 25 s in-flight HTTP request.

## 1.9.5-universal-carrier

- Added MTS Link `seichannel` multipath profiles: clients can pass `mc-lanes`,
  `mc-control-lanes`, `mc-connect-parallel`, `mc-min-ready`, and
  `mc-max-streams-per-lane` so Windows, Android, and the server use the same
  lane pool.
- Added a v2 SEI lane header in the `mtsRTC` core. Legacy single-lane links
  remain on the old frame format; multipath lanes filter by lane id.
- Updated MTS Link docs and examples to recommend 12 lanes, one reserved
  control lane, and matching traffic/liveness defaults.
- Replaced the Android main screen with the dark live runtime UI: status badge,
  session traffic counter, transport indicators, metrics grid, profile cards,
  event log, and bottom navigation for home/profiles/traffic/settings.
- Added Android service telemetry broadcasts for carrier, transport, lanes,
  uptime, SOCKS probe latency, session bytes, current speed, and recent status
  events.
- Fixed Android MTS defaults to use `seichannel` 30 FPS by default, MTS
  liveness timeout `60s` with `3` failures, a single shutdown/reconnect lock,
  generation-guarded reconnects, and explicit `link=` pass-through to the Go
  core.

## Windows 0.5.5-beta

- Bumped Windows package metadata and build output to `0.5.5-beta`.
- Rebuilt the bundled core from the same `mtsRTC` branch used by Android
  `1.9.5`.
- Documented the 12-lane MTS Link profile and updated release maintenance notes
  for the new package/tag names.

## 1.9.4-universal-carrier

- Raised the MTS Link traffic payload floor dynamically to `frag * 8` instead of keeping the old 1200-byte profile cap that could terminate the control stream at 1208-byte frames.
- Older saved MTS Link profiles with `traffic-max-payload=1200` are auto-raised by the Android bridge.

## Windows 0.5.4-beta

- Applied the same dynamic MTS Link traffic payload floor to generated Windows core configs.
- Full tunnel now routes selected DNS server host routes outside the TUN adapter and uses short UDP sessions to reduce UDP-over-SOCKS5 failure storms.

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
