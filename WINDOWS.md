# XLTD VPN Windows beta

Windows is versioned separately from Android.

- Android current line: `1.6.x-universal-carrier`
- Windows beta line: `0.1.x-beta`

The first Windows beta is intentionally conservative:

- Native WinForms GUI.
- Local profile storage under `%APPDATA%\XLTD_Vpn\windows-profiles.json`.
- Same `olcrtc://` URI parser contract as Android.
- Bundled `olcrtc.exe` built from the local `openlibrecommunity/olcrtc` source snapshot.
- Local SOCKS mode on `127.0.0.1:10808`.
- Optional Windows user proxy mode while connected. It stores the previous proxy settings and restores them on stop/exit.

The beta does not install a permanent driver or Windows service. Full TUN/Wintun mode is the next large Windows step because it needs administrator rights, driver handling, route/DNS restoration, and careful rollback.

## Build

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

Output:

```text
dist/windows/XLTD_Vpn-Windows-0.1.0-beta-win-x64.zip
```

The package contains:

- `XLTD_Vpn_Windows.exe`
- `tools/olcrtc.exe`
- `tools/data/names`
- `tools/data/surnames`

The default package is framework-dependent and expects the .NET Desktop Runtime already installed. Use `-SelfContained` for a larger package that carries the runtime:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1 -SelfContained
```

## Versioning

Feature parity changes should move Android and Windows in parallel by intent, but each platform keeps its own patch number:

- Android: `1.6.4`, `1.7.0`, etc.
- Windows: `0.1.1-beta`, `0.2.0-beta`, etc.

Small platform-only bugfixes update only the platform they touch.
