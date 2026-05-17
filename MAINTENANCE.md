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

## Versioning

- Bump `versionCode` for every user-visible or behavioral improvement.
- Bump `versionName` with the same intent, for example `1.6.3-universal-carrier`.
- Add a short entry to `CHANGELOG.md` before publishing.

## GitHub publishing

The canonical private repository is `l1ch666/XLTD_Vpn`.

Before publishing:

1. Keep generated outputs out of commits: `.tmp/`, `.external/`, `.gradle/`, `build/`, `app/build/`, `dist/`, and generated `app/libs/*.aar`.
2. Commit only source, scripts, and documentation changes.
3. Build the debug APK with `scripts/build_apk.ps1`.
4. Upload the APK from `dist/` to a GitHub release tag matching the app version, for example `v1.6.3`.
5. Include the SHA256 printed by the build helper in the release notes.
