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
- Bump `versionName` with the same intent, for example `1.6.2-universal-carrier`.
- Add a short entry to `CHANGELOG.md` before publishing.

## GitHub publishing

This folder is currently a source snapshot, not a git checkout. Before publishing:

1. Initialize a git repository or clone the target GitHub repository.
2. Commit the source files, excluding generated outputs such as `.tmp/`, `.external/`, `build/`, and `app/build/`.
3. Decide whether `app/libs/olcrtccombo.aar` should be published as a binary artifact or rebuilt by users locally.
