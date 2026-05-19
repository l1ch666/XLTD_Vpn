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

Both Android and Windows build helpers apply tracked patches from `patches/`
to the local `.external/olcrtc` checkout before compiling bundled core code.

## Versioning

- Bump `versionCode` for every user-visible or behavioral improvement.
- Bump `versionName` with the same intent, for example `1.9.0-universal-carrier`.
- Add a short entry to `CHANGELOG.md` before publishing.
- Keep Windows versioning separate under `windows/XLTD.Vpn.Windows`:
  - Android stable line: `1.8.x-universal-carrier`.
  - Windows beta line: `0.4.x-beta`.
  - Shared feature-level changes should move the first/second version numbers in parallel by intent.
  - Small platform-only bugfixes update only the third number for that platform.

## Windows beta build

Build the Windows GUI and bundled core:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

The helper writes `dist/windows/XLTD_Vpn-Windows-0.5.0-beta-win-x64.zip` and prints SHA256 for the GitHub pre-release.

## GitHub publishing

The canonical private repository is `l1ch666/XLTD_Vpn`.

Before publishing:

1. Keep generated outputs out of commits: `.tmp/`, `.external/`, `.gradle/`, `build/`, `app/build/`, `dist/`, and generated `app/libs/*.aar`.
2. Commit only source, scripts, and documentation changes.
3. Build the debug APK with `scripts/build_apk.ps1`.
4. Build the Windows beta package with `scripts/build_windows.ps1` when a Windows change is included.
5. Upload Android APKs to stable Android tags such as `v1.9.0`.
6. Upload Windows beta zips to pre-release Windows tags such as `windows-v0.5.0-beta`.
7. Include the SHA256 printed by each build helper in the release notes.
