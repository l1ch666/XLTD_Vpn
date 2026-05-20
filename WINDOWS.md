# XLTD VPN Windows alpha

Windows is versioned separately from Android.

- Android alpha line: `0.0.1-alpha`
- Windows alpha line: `0.0.1-alpha`

The current Windows alpha keeps the conservative local SOCKS/proxy path and adds an experimental full tunnel path:

- Native WinForms GUI.
- Local profile storage under `%APPDATA%\XLTD_Vpn\windows-profiles.json`.
- Same `olcrtc://` URI parser contract as Android.
- Bundled `olcrtc.exe` built from `l1ch666/mtsRTC` `mtslink-universal-carrier` by default.
- Local SOCKS mode on `127.0.0.1:10808`.
- Optional Windows user proxy mode while connected. It stores the previous proxy settings and restores them on stop/exit.
- Experimental full tunnel mode through bundled `tun2socks.exe` and `wintun.dll`. This mode requires launching the app as Administrator.
- Bundled `ffmpeg.exe` for `videochannel` profiles.
- Experimental `mtslink` carrier profiles over H.264 media (`seichannel` for VPN traffic, `videochannel` for diagnostics).
- Experimental Xray backend profiles (`vless`, `vmess`, `trojan`, `shadowsocks`, `socks`, `http`, and raw Xray JSON) through bundled `xray.exe`.

The beta does not install a permanent Windows service. Full tunnel route/DNS setup is applied at connect time and rolled back at stop/exit. If a carrier reconnect loops through the tunnel on a specific network, switch back to local SOCKS or user proxy mode for that profile until the next tunnel hardening pass.

## Build

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

Output:

```text
dist/windows/XLTD_Vpn-Windows-0.0.1-alpha-win-x64.zip
```

The package contains:

- `XLTD_Vpn_Windows.exe`
- `tools/olcrtc.exe`
- `tools/tun2socks.exe`
- `tools/wintun.dll`
- `tools/ffmpeg.exe`
- `tools/xray.exe`
- `tools/geoip.dat`
- `tools/geosite.dat`
- `tools/data/names`
- `tools/data/surnames`

The default package is framework-dependent and expects the .NET Desktop Runtime already installed. Use `-SelfContained` for a larger package that carries the runtime:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1 -SelfContained
```

## Versioning

Feature parity changes should move Android and Windows in parallel by intent, but each platform keeps its own patch number:

- Android: `0.0.1-alpha`, then `0.0.2-alpha`, etc. while Xray is isolated.
- Windows: `0.0.1-alpha`, then `0.0.2-alpha`, etc. while Xray is isolated.

Small platform-only bugfixes update only the platform they touch.
