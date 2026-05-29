# XLTD VPN — Windows · Components

> WinForms custom controls. All sizes px. Colors → `design-tokens.json` (v3 graphite/blue/lime,
> with `source_value` = original light color and `applies_to` = the member to edit).

## RoundedPanel  ·  `Controls/RoundedPanel.cs`
- The one card primitive. `Radius` (default 22; cards use 26), `FillColor`, `BorderColor`.
- Painted via `UiShapes.RoundedRect` + `SmoothingMode.AntiAlias`, transparent backcolor.
- v3: `FillColor = surface #181B22`, `BorderColor = line #262A33` (was white / #E8EAEE).
- `PanelCard()` factory = radius 26, margin 8.

## PillButton  ·  `Controls/PillButton.cs`
- Rounded button with `FillColor / HoverColor / PressedColor / TextColor`.
- **Primary** (`StylePrimary`): fill `primary #2D7DFF` (or blue→lime gradient), hover `#4F8BFF`,
  press `#1A5FE0`, text white. Was solid black.
- **Secondary** (`StyleSecondary`): fill `surface #181B22` + 1px `line`, text `primary_light #7DA8FF`.
  Was `#F0F2F5` / black. Used for New · Delete · Save (width 108).
- **Danger**: surface + 1px line, text `vp8 #E17055` — the Stop button (see `assets/ic_stop.svg`).

## Owner-drawn profile row  ·  `DrawProfileItem`
- Rounded card (radius 18) inside a 70px ListBox item, inset 4/6px.
- Default fill `#10131A`, selected fill raised `#15171F` + 1px `line_strong #2A3548`.
- Title Segoe UI 10 Bold (`ink`, white when selected); meta Segoe UI 8
  (`meta #7C8089`, `#D7DBE2` when selected). v3 adds a lime active dot + transport glyph tile.

## SectionLabel  ·  `SectionLabel()`
- Segoe UI 10 Bold, `meta #7C8089`. Used for "Profile" / "Runtime log" headers.

## TextBox (styled)  ·  `StyleTextBox`
- `FixedSingle` border, fill `surface_alt #10131A` (was #F0F2F5), text `ink`.
- Name box single-line; Link box multiline + vertical scrollbar.

## ComboBox · route mode  ·  `routeModeBox`
- `DropDownStyle = DropDownList`, 3 fixed options. v3 → 3 selectable cards (radius 14);
  selected = 1px `primary #2D7DFF` border + `#15182B` fill + "admin · active" tag in `primary_light`.

## Runtime log box  ·  `logBox` + `AppendLog`
- Read-only multiline, **Consolas 9**, fill `surface #181B22` (was white), no border.
- Timestamps `HH:mm:ss`; noise filtered by `ShouldHideNoisyCoreLine`.

## Shared icons  ·  `assets/`
- `ic_nav_home/profiles/traffic/settings.svg` — same set as Android, for the v3 nav rail.
- `ic_nav_log.svg` — Runtime log rail item.
- `ic_transport_sei/vp8/video/data.svg` — profile glyphs (lime/terracotta/blue/blue).
- `ic_power.svg` — Connect (primary, white on gradient). `ic_stop.svg` — Stop (danger, vp8).
- `signal_bars.svg` — profile quality bars (same component as Android).
- `ic_launcher.png` — bunny mascot for the title-bar.

## Status / metric (v3 dashboard)
- **Status hero**: lime "Tunnel active" badge (8px dot, glow) + 48px mono speed + context line;
  Stop button is a danger pill, NOT the brightest element.
- **Metric card**: surface #181B22, radius 14, 1px line; 10px mono `meta` label + 24px mono white
  value + `primary_light` delta + a 10-bar sparkline (filled bars = blue→deep gradient).
