# Maintenance Notes

## Local checks

Run the parser contract test after URI, profile, or transport changes:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_parser_contract_test.ps1
```

Full APK verification still requires a generated combo AAR:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1
```

The helper builds a debug APK and copies it into `dist/` for release upload.

For a combo-AAR build from source:

```bash
bash scripts/build_combo_aar.sh
gradle clean :app:assembleDebug
```

`scripts/build_combo_aar.sh` also prepares Android ffmpeg assets for
`videochannel`. Generated binaries under `app/src/main/assets/ffmpeg/*/ffmpeg`
stay out of git; rebuild the AAR/APK to refresh them.

Both Android and Windows build helpers use `l1ch666/mtsRTC`
`mtslink-universal-carrier` by default. Set `OLC_REPO`, `OLC_REF`, and
`OLC_PATCHES` only when intentionally testing another olcRTC source.

## Versioning

- Bump `versionCode` for every user-visible or behavioral improvement on
  Android.
- Bump `versionName` with the same intent:
  - stable Android line: `1.9.x-universal-carrier`;
  - isolated Xray alpha line: `0.0.x-alpha`.
- Add a short entry to `CHANGELOG.md` before publishing.
- Keep Windows versioning separate under `windows/XLTD.Vpn.Windows`:
  - Android stable line: `1.9.x-universal-carrier`.
  - Windows beta line: `0.5.x-beta`.
  - Android/Windows Xray alpha line: `0.0.x-alpha`.
  - Shared feature-level changes should move the first/second version numbers in parallel by intent.
  - Small platform-only bugfixes update only the third number for that platform.

## Windows build

Build the Windows GUI and bundled core:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

The helper writes the current Windows package under `dist/windows/` and prints
SHA256 for the GitHub pre-release. On the Xray alpha branch the expected package
name is `XLTD_Vpn-Windows-0.0.3-alpha-win-x64.zip`.

## GitHub publishing

The canonical private repository is `l1ch666/XLTD_Vpn`.

Before publishing:

1. Keep generated outputs out of commits: `.tmp/`, `.external/`, `.gradle/`, `build/`, `app/build/`, `dist/`, and generated `app/libs/*.aar`.
2. Commit only source, scripts, and documentation changes.
3. Build the debug APK with `scripts/build_apk.ps1`.
4. Build the Windows beta package with `scripts/build_windows.ps1` when a Windows change is included.
5. Upload Android APKs to stable Android tags such as `v1.9.4`, or to alpha
   tags such as `xltd_xray_alpha_0.0.3` when working on the alpha branch.
6. Upload Windows beta zips to pre-release Windows tags such as
   `windows-v0.5.4-beta`, or to the matching alpha release when working on the
   Xray alpha branch.
7. Include the SHA256 printed by each build helper in the release notes.

## Cleanup Rules

Safe to delete:

- `.tmp/` parser-test scratch output.
- root-level ignored binaries in `.external/olcrtc/`, for example
  `.external/olcrtc/olcrtc.exe`.
- regenerated packages under `dist/` when a fresh release build will recreate
  them.

Keep unless intentionally refreshing the toolchain:

- `.external/olcrtc/`, `.external/xray-core/`, and `.external/tun2socks/`
  source checkouts.
- `.external/ffmpeg*` and `.external/xray*` downloaded runtime assets.
