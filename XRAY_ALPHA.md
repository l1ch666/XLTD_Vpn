# XLTD VPN Xray alpha

This branch is the isolated `0.0.2-alpha` line for adding an Xray backend to
XLTD VPN without breaking the current olcRTC/MTS Link client path.

## Scope

- Android app version: `0.0.2-alpha`.
- Windows app version: `0.0.2-alpha`.
- Xray-core version pinned by build scripts: `v26.5.9`.
- Android bundles an official native Xray binary under `assets/xray/<abi>/xray`.
- Windows bundles `tools/xray.exe`, `geoip.dat`, and `geosite.dat`.
- Existing `olcrtc://` profiles still run through the old olcRTC backend.
- Xray profiles run through a separate local SOCKS backend on `127.0.0.1:10808`.

## Supported profile formats

The alpha parser accepts copied profile text that contains one of these formats:

```text
vless://...
vmess://...
trojan://...
ss://...
socks://...
http-proxy://...
xray://<base64url-or-url-encoded-json>
{ raw Xray JSON config }
```

Share-link parsing covers common Xray stream settings:

```text
security=tls|reality
type=tcp|ws|grpc|http|h2|xhttp|splithttp|kcp|quic
sni=...
fp=...
pbk=...
sid=...
spx=...
host=...
path=...
serviceName=...
headerType=...
quicSecurity=...
key=...
```

Raw JSON configs are accepted too. The clients inject a local no-auth SOCKS
inbound tagged `xltd-socks-in`, so a normal Xray client config can be pasted
without manually adding the local listener.

Windows and Android strip UTF-8 BOM/zero-width prefixes before writing the
runtime JSON. This avoids Xray errors such as `invalid character 'ГЇ' looking
for beginning of value` when a profile was copied from a BOM-prefixed file.

## Android build

The combo build now also prepares Android Xray assets:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' scripts/build_combo_aar.sh
powershell -ExecutionPolicy Bypass -File scripts/build_apk.ps1
```

Defaults:

```text
ANDROID_XRAY_VERSION=v26.5.9
ANDROID_XRAY_ABIS=arm64-v8a
```

To build more ABIs:

```powershell
$env:ANDROID_XRAY_ABIS = "arm64-v8a,armeabi-v7a,x86_64,x86"
& 'C:\Program Files\Git\bin\bash.exe' scripts/build_combo_aar.sh
```

## Windows build

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1 -Runtime win-x64
```

Output:

```text
dist/windows/XLTD_Vpn-Windows-0.0.2-alpha-win-x64.zip
```

The build downloads the matching official Xray-core Windows asset and packages
it next to the existing olcRTC, ffmpeg, tun2socks, and Wintun tools.

## Alpha notes

- This is not a replacement for the olcRTC backend; it is a parallel backend.
- UDP is enabled on the local SOCKS inbound, but platform VPN behavior still
  depends on tun2socks and Android/Windows routing.
- Android executes the bundled native `xray` binary from app storage. Keep the
  target SDK/runtime policy in mind before promoting this out of alpha.
- The first packaged ABI is `arm64-v8a`. Broader APK publishing should include
  the other Android Xray assets or split APKs.
