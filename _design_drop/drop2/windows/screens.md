# XLTD VPN — Windows · Screens

> Source: `windows/XLTD.Vpn.Windows/` — a **WinForms** desktop app with custom-painted
> controls (no WinUI/WPF). Palette = v3 graphite/blue/lime; see `design-tokens.json`
> (`source_value` = the original LIGHT color each token replaces, `applies_to` = the
> `MainForm.cs` member to change).

## The window (`MainForm`)
- Single top-level window, 1080×740 (min 960×660), centered, default font **Segoe UI 10**.
- bg `#0E1014` (was `#F5F6F8`). Root = `TableLayoutPanel`, padding 20px:
  - **Left column 350px** — profiles card (title + version + owner-drawn `ListBox`).
  - **Right column (fill)** — 3 stacked rows: **Editor 250px** · **Connection 168px** · **Log (fill)**.
- v3 adds a **220px nav rail** as a new left-most column (Главная · Профили · Трафик · Настройки ·
  Runtime log), pushing the profiles list into the "Профили" view. Active item = `primary #2D7DFF`
  text + a 2px left bar; inactive = `meta #7C8089`.

> The shipped app is one master-detail window. v3 reframes it as the **same dark cockpit as
> Android**, split into rail-driven views. The panels below map 1:1 to `MainForm.cs` build methods.

---

## A · Profiles list  ·  left card + `DrawProfileItem`
- `RoundedPanel` (radius 26, fill `surface #181B22`, border `line #262A33`), padding 18.
- **Title** "XLTD VPN" (Segoe UI 26 Bold, `ink #F0F1F4`) + **version** "Windows beta <ver>"
  (`meta #7C8089`). v3 puts the **bunny mascot** in the window title-bar to the left of the name.
- **ListBox** — `DrawMode=OwnerDrawFixed`, `ItemHeight=70`, `BorderStyle=None`.
  Each item drawn by `DrawProfileItem`: a rounded card (inset 4/6px, radius 18), title
  (Segoe UI 10 Bold) + meta `carrier / transport` (Segoe UI 8). Selected row in source = solid
  black; **v3** = raised surface `#15171F` + 1px `line_strong #2A3548` + a lime active dot.

## B · Profile editor  ·  `BuildEditor`
- `RoundedPanel` (radius 26), 4 rows: SectionLabel "Profile" (30px) · **name box** (40px) ·
  **link box** (fill, multiline, vertical scroll) · **button row** (50px).
- **Name box / Link box** — `TextBox`, fill `surface_alt #10131A` (was `#F0F2F5`), `ink` text,
  border `line`. Link placeholder: `olcrtc://carrier?transport<params>@room#64hexkey$comment`.
- **Buttons** (RightToLeft `FlowLayoutPanel`): **Save · Delete · New**, each a secondary `PillButton`
  width 108. Save parses the URI (`OlcUriParser.Parse`) before persisting (`ProfileStore`).

## C · Connection  ·  `BuildConnection`
- `RoundedPanel` (radius 26), 2-col grid (fill + 168px):
  - **statusLabel** (Segoe UI 13 Bold, `ink`) — e.g. "Connected. Local SOCKS is ready." +
    primary **Connect/Stop** `PillButton` (168px). v3: a **status hero** — lime "Tunnel active"
    badge, big mono download speed, context line `mtslink · SEI · 12 lanes · 74 ms`.
  - **metaLabel** (`meta`) — "Local SOCKS: 127.0.0.1:10808" / "<carrier> / <transport> - SOCKS …".
  - **routeModeBox** `ComboBox` (DropDownList) — 3 options (Local SOCKS / Windows user proxy /
    Full tunnel · Wintun). v3 renders these as **3 selectable cards** (radius 14), selected =
    1px `primary` border + "admin · active" tag.
  - **hint** (`meta_dim`) — whether Full tunnel is available (admin) or needs elevation.
- **Toggle** (`ToggleConnectionAsync`): start core → `WaitForSocksAsync` (≤45s) → apply route mode
  (user proxy or Wintun tunnel). Errors restore proxy + stop tunnel + relabel "Connect".

## D · Runtime log  ·  `BuildLogs`
- `RoundedPanel` (radius 26): SectionLabel "Runtime log" + a read-only multiline **Consolas 9**
  `TextBox`, fill `surface #181B22` (was white), text `#C8CCD4`.
- Every line is timestamped `HH:mm:ss` (`AppendLog`). Noisy core lines
  (`[ice]/[dtls]/[sctp]` TRACE/DEBUG, `wsasendto` errors) are filtered (`ShouldHideNoisyCoreLine`).
- v3 colorises by tag: OK = lime, status = primary_light, warn = vp8.

---

## v3 dashboard layout (target — what `reference.html` shows)
1. **Title-bar** — bunny tile + "XLTD VPN" + mono version chip; center shows live context
   (`mtslink · seichannel · 12 lanes`); window controls right (— ▢ ×, × in vp8).
2. **Nav rail 220px** — 4 shared icons + Runtime log; bottom mono block (SOCKS / mode / core).
3. **Status hero** — full-width: lime badge + big speed + context line + Stop (danger) + session.
4. **Metrics 4-wide** — rx · tx · latency · uptime, each with a 10-bar sparkline (lime/primary).
   (The horizontal layout + history is desktop-only; Android shows 2×2 without sparklines.)
5. **Two columns** — Profiles (with signal bars) + live Events log (tagged).
6. **Route mode** — 3 cards (Local SOCKS / user proxy / Full tunnel), selected highlighted.
