# XLTD VPN — Windows design package

Self-contained reference for the **Windows client** (WinForms, source `windows/XLTD.Vpn.Windows/`).
Open `reference.html` to *see* it; read the rest to *build* it. **Separate from the Android package.**

| File | What it is |
|---|---|
| `reference.html` | Visual gallery — the full dark dashboard window (title-bar · nav rail · status hero · metrics · profiles + log · route mode), plus an asset board & palette. **Open this first.** |
| `design-tokens.json` | Machine-readable colors / radii / spacing / type. Each color lists `source_value` (the original LIGHT color it replaces) and `applies_to` (the `MainForm.cs` member to change). |
| `screens.md` | The window + each panel, mapped to `BuildEditor` / `BuildConnection` / `BuildLogs` / `DrawProfileItem`. |
| `components.md` | `RoundedPanel`, `PillButton`, owner-drawn profile row, route-mode `ComboBox`, Consolas log, shared icons. |
| `assets/` | `ic_launcher.png` · `ic_nav_*.svg` ×5 (incl. log) · `ic_transport_*.svg` ×4 · `ic_power.svg` · `ic_stop.svg` · `signal_bars.svg`. |

**Palette:** v3 — graphite `#0E1014` + electric blue `#2D7DFF` + lime `#C9FF3D`, the **same cockpit
as Android**. The shipped source is a light WinForms utility; this package retargets it to dark.
Migration is mechanical: every token's `source_value` + `applies_to` names the exact color and
control to change. Nav rail / status hero / sparkline metrics / route-mode cards are the v3
additions on top of the original 4-panel master-detail layout.
