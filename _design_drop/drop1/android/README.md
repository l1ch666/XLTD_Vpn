# XLTD VPN — Android design package

Self-contained reference for the **Android client** (`com.s1dechain.olcrtcvpn`,
source `app/src/main/java/com/s1dechain/olcrtcvpn/MainActivity.java`). Built for hand-off:
open `reference.html` to *see* it; read the rest to *build* it.

| File | What it is |
|---|---|
| `reference.html` | Visual gallery — all 4 tabs + editor rendered as phones, plus an asset board & palette. **Open this first.** |
| `design-tokens.json` | Machine-readable colors / radii / spacing / type. Each color maps to its original `COLOR_*` constant (`source_const`) and the pre-rebrand value (`source_value`). |
| `screens.md` | Every screen documented layer-by-layer, mapped to the `build*Tab` methods. |
| `components.md` | Every UI atom (chip, metric card, profile row, signal bars, event row, buttons…) with exact specs. |
| `assets/` | `ic_launcher.png` (bunny mascot) · `ic_nav_*.svg` ×4 · `ic_transport_*.svg` ×4 · `signal_bars.svg`. SVGs use `currentColor` — tint per state. |

**Palette:** v3 — graphite `#0E1014` + electric blue `#2D7DFF` (primary) + lime `#C9FF3D` (live pulse).
The UI is 100% programmatic Java views (no XML layouts, no Material Components); retheme by
editing the `COLOR_*` constants block at the top of `MainActivity.java`.
