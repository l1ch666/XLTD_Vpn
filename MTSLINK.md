# MTS Link carrier

This repo carries a local olcRTC fork patch for an experimental `mtslink`
carrier. It joins a public MTS Link room as a guest and uses olcRTC
`videochannel` over H.264 media.

## Room link

Use a public MTS Link room URL:

```text
https://my.mts-link.ru/j/167846474/19645959806
```

If automatic session discovery fails, open the room once in a browser and copy
the expanded URL with `/stream-new/<sessionId>`:

```text
https://my.mts-link.ru/j/167846474/19645959806/stream-new/18867526566
```

## Server config

Create `server-mtslink.yaml`:

```yaml
mode: srv
auth:
  provider: mtslink
room:
  id: "https://my.mts-link.ru/j/167846474/19645959806"
  channel: default
crypto:
  key: "64_hex_key_here"
net:
  transport: videochannel
  dns: "1.1.1.1:53"
video:
  codec: qrcode
  width: 640
  height: 360
  fps: 15
  bitrate: "1200k"
  hw: none
  qr_recovery: low
ffmpeg: "ffmpeg"
debug: false
```

Run:

```bash
./olcrtc server-mtslink.yaml
```

## Client URI

The matching client profile URI is:

```text
olcrtc://mtslink?videochannel<video-w=640&video-h=360&video-fps=15&video-bitrate=1200k>@https%3A%2F%2Fmy.mts-link.ru%2Fj%2F167846474%2F19645959806#64_hex_key_here$MTS%20Link
```

Windows `0.4.0-beta` bundles `ffmpeg.exe` and can run this profile. Android
parses and stores the profile, but runtime `videochannel` still needs an
ffmpeg-backed Android core.
