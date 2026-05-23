# MTS Link Carrier

`XLTD VPN` stable builds use the `l1ch666/mtsRTC` `mtslink-universal-carrier`
fork for the experimental `mtslink` carrier. It joins a public MTS Link room as
a guest, negotiates H.264/Opus media, and carries VPN traffic through
`seichannel` H.264 SEI payloads.

Recommended VPN mode:

```text
mtslink + seichannel
```

`videochannel` remains available for legacy visible-video diagnostics, but it
is not the default MTS Link VPN path.

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

## Server Config

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
  transport: seichannel
  dns: "1.1.1.1:53"
sei:
  fps: 30
  batch_size: 8
  fragment_size: 700
  ack_timeout_ms: 10000
liveness:
  interval: 20s
  timeout: 15s
  failures: 6
traffic:
  max_payload_size: 5600
  min_delay: 4ms
  max_delay: 18ms
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
olcrtc://mtslink?seichannel<fps=30&batch=8&frag=700&ack-ms=10000&liveness-interval=20s&liveness-timeout=15s&liveness-failures=6&traffic-max-payload=5600&traffic-min-delay=4ms&traffic-max-delay=18ms&mts-peer-update=1&mts-silent-audio=1&mts-force-video=1>@https%3A%2F%2Fmy.mts-link.ru%2Fj%2F167846474%2F19645959806#64_hex_key_here$MTS%20Link
```

For MTS Link, keep `traffic.max_payload_size` at least `fragment_size * 8`.
The Windows and Android clients auto-raise older saved `traffic-max-payload=1200`
profiles to that floor, so larger SEI frames do not hit the old artificial cap.

Windows `0.5.4-beta` bundles `ffmpeg.exe`, `wintun.dll`, and the updated local
core. Android `1.9.4-universal-carrier` can run media transports when the combo
AAR is built with the Android ffmpeg asset or the profile supplies
`android-ffmpeg=<path>`.

`1.9.4` / `0.5.4-beta` build the core from the patched `l1ch666/mtsRTC`
fork without rebasing onto newer upstream olcRTC. The fork switches
`seichannel` to per-fragment ACKs. This
targets the case where MTS joined successfully, SOCKS became ready, and then
the control stream died with `seichannel ack timeout` or missed pongs under
traffic bursts.

## MTS Link Diagnostics

The Windows client passes these optional URI parameters into the local core as
environment variables:

- `mts-peer-update=1` keeps the post-join peer update enabled.
- `mts-silent-audio=1` sends silent Opus RTP on the browser-like audio publisher.
- `mts-force-video=1` asks MTS Link to create a video-capable conference.
- `mts-video-test=1` publishes a synthetic visible H.264 camera instead of the VPN
  video track. Use it only to debug whether the MTS lobby shows the bot camera.
- `mts-video-codec=h264` is the default diagnostic camera codec; `vp8` is only a
  legacy probe.
