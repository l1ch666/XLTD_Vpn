# XLTD VPN — Android · Components

> Atom-level specs. All backgrounds are `GradientDrawable` built by
> `roundedDrawable(fill, radiusDp, stroke, strokeDp)`. Sizes in dp, text in sp.
> Colors reference `design-tokens.json` (v3 graphite/blue/lime).

## Card  ·  `card()`
- bg `surface #181B22`, radius 16dp, 1dp `line #262A33` border, padding 14dp all sides.
- Stacked with 6dp vertical margins (`lpMatchWrap`).

## Status badge  ·  in `buildHero`
- Horizontal pill: 8dp **status dot** (radius 8, no border) + 7dp gap + 11sp label `text_label`.
- bg `surface_alt #1A1D24`, radius 20dp, 1dp `line` border, padding 9/6/12/6.
- Dot color: connected → `signal #C9FF3D`, connecting → `primary #2D7DFF`, disconnected → `border #3A3F49`.

## Connect button  ·  `buildConnectButton` + `gradientButton()`
- Full width, gravity center, 15sp bold, padding 16/15.
- **Gradient** LEFT_RIGHT `primary #2D7DFF → signal #C9FF3D`, radius 16dp (connect & disconnect states).
- **Connecting** state swaps to flat bg `surface #181B22` + 1dp `line` border, label `text_bright`.

## Transport chip  ·  `addTransportChip` / `refreshTransportChips`
- Horizontal: 6dp **dot** (radius 6) + 5dp gap + 11sp label. Padding 10/6, margins 3dp L/R.
- **Inactive**: bg `surface #181B22`, radius 20dp, 1dp `line` border; dot `#3A3F49`; label `text_dim`.
- **Active**: bg `#0F1A33` (was #1E1E2E), 1dp `primary #2D7DFF` border; dot = **transport accent**
  (SEI=lime, VP8=terracotta, Video=blue, Data=blue); label `primary_pale #C5D9FF`.
- Tap → `switchSelectedTransport(tag)` rewrites the selected profile URI's transport block.

## Metric card  ·  `metricValue`
- Column in a weighted row, bg `surface #181B22`, radius 12dp, 1dp `line` border, padding 12/10, margin 4dp.
- **Label** 10sp mono `text_muted` (e.g. "↓ ВХОДЯЩИЙ").
- **Value** 18sp mono `text` (e.g. "1.84 MB/s").
- **Delta** 10sp mono `primary #2D7DFF` (e.g. "SEI · 12 lanes" / "один канал").

## Profile row  ·  `profileRow`
- Horizontal, bg `surface #181B22`, radius 14dp, padding 10/9.
  Border: selected → `line_strong #2A3548`, else `line #262A33`.
- **Active dot** 7dp: selected → `signal #C9FF3D` (lime), else `line #262A33`.
- **Glyph tile** 32×32, radius 10dp, bg `surface_alt #1A1D24`, glyph `primary_light #7DA8FF`, 16sp.
  Glyph by transport — replace Unicode with `assets/ic_transport_*.svg`: SEI ↯ · VP8 ♪ · Video ▣ · Data ⌁.
- **Text**: title (bold `text_secondary`) = `displayCarrier · transportShort`; meta (11sp `text_dim`) =
  e.g. "seichannel · lanes=12 · fps=30".
- **Right**: signal bars (Home/compact) OR "изменить" text-action (Profiles/full).

## Signal bars  ·  `SignalBarsView` → `assets/signal_bars.svg`
- 4 ascending rounded bars. Width 3dp, gap 2dp, radius 2dp, heights factor [0.3,0.53,0.76,0.99].
- Filled+active `primary #2D7DFF`, filled+inactive `primary_deep #1A5FE0`, empty `line #262A33`.
- Level rule in `profileQualityLevel` (latency thresholds 80/180/350 ms).

## Event row  ·  `eventRow`
- Horizontal, top-aligned, padding 5dp T/B.
- **Time** 10sp mono `border_dim`, fixed 42dp.
- **Tag** pill 10sp mono, padding 5/2, bg `surface_alt #1A1D24`, radius 5dp; color by tag
  (OK=lime, DNS=blue, WARN=terracotta, TUN/LOG=text_dim). 8dp right gap.
- **Message** 11sp `text_dim`, weighted fill.

## Inputs  ·  `editText` / `settingInput`
- bg `surface_input #10131A`, radius 12dp, 1dp `line` border, padding 12dp, 14sp `text`,
  hint `text_muted`. Multiline URI box ≥6 lines, top-start gravity. No autosuggest.

## Buttons (small)  ·  `primarySmallButton` / `secondarySmallButton`
- **Primary**: 14sp bold white on the blue→lime **gradient**, radius 16dp, padding 14/12.
- **Secondary**: same metrics, label `primary_pale #C5D9FF`, bg `surface #181B22` + 1dp `line` border.

## Section title  ·  `sectionTitle`
- 10sp mono **bold** `text_muted`, UPPERCASE content (СЕРВЕРЫ / ПРОФИЛИ / СОБЫТИЯ / СЕССИЯ).

## Text-action  ·  `smallAction`
- 10sp mono `primary #2D7DFF`, padding 8/5, clickable ("+ добавить", "изменить", "удалить").

## Launcher icon  ·  `assets/ic_launcher.png`
- 192×192 lop-eared bunny mascot, white line on solid black (`ic_launcher_background #000000`).
  The only place the mascot currently appears (recommendation: also use it in connected states).
