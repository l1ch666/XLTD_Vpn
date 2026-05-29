# XLTD VPN — Android · Screens

> Source of truth: `app/src/main/java/com/s1dechain/olcrtcvpn/MainActivity.java`
> The whole UI is built **programmatically in Java** — no XML layouts. Each screen is a method
> (`buildHomeTab`, `buildProfilesTab`, …) that appends views into a vertical `ScrollView`
> (`content`) sitting above a fixed `bottomNav` bar. Switching tabs calls `renderActiveTab()`
> which clears `content` and rebuilds.
> Palette = v3 graphite/blue/lime (see `design-tokens.json`; field `source_const` maps each
> token back to the original `COLOR_*` constant for migration).

## Shell (every screen)
- **Root**: vertical `LinearLayout`, bg `bg #0E1014`.
- **Scroll body**: `ScrollView` → `content` LinearLayout, padding L/R 18dp, T/B 10dp, weight 1.
- **Bottom nav**: fixed, bg `#10131A`, top border 1dp `#171A20`, padding 10/8dp. 4 equal-weight items.
  - Each item: icon glyph (replace with `assets/ic_nav_*.svg`) over a 9sp bold UPPERCASE label,
    centered, line-spacing 0.95. Active = `primary #2D7DFF`, inactive = `border #3A3F49`.
  - Order: Главная(0) · Профили(1) · Трафик(2) · Настройки(3).
- On launch: status set to "Готов к подключению." or "Core не найден…" if the native combo AAR is missing.

---

## 1 · Home (`buildHomeTab`) — TAB_HOME
Vertical stack, top → bottom:

1. **Status bar row** (`buildStatusBar`) — `XLTD VPN` (mono, text_muted) on the left,
   `↓ <rate>` (mono, text_dim) right-aligned. Padding bottom 8dp.
2. **Hero** (`buildHero`) — centered column:
   - **Status badge** pill: 8dp status dot + 11sp label. bg `surface_alt #1A1D24`, radius 20dp,
     1dp `line` border. Dot color by state (lime/blue/dim). Label text = `statusBadgeText()`
     e.g. "Подключено · MTS Link".
   - **Hero counter**: 44sp MONO value + 16sp MONO unit (rx+tx session bytes, split by `splitBytes`).
   - **Sub-caption**: 12sp text_muted — "передано за сессию" / "ожидание подключения".
3. **Connect button** (`buildConnectButton`) — full width, see `design-tokens.json#connect_button`.
   Gradient (blue→lime) for connect/disconnect; flat surface for the connecting "Остановить" state.
4. **Transport chips** (`buildTransportChips`) — centered row of 4: SEI · VP8 · Data · Video.
   Tapping rewrites the selected profile's URI transport (`switchSelectedTransport`) and, if running,
   stops + reconnects after 700ms. See component spec.
5. **Metrics 2×2** (`buildMetricsGrid`) — `↓ ВХОДЯЩИЙ` / `↑ ИСХОДЯЩИЙ` (row 1), `ЗАДЕРЖКА` / `АПТАЙМ`
   (row 2). Each is a metric card.
6. **Servers panel** (`buildProfilesPanel(false)`) — section title "СЕРВЕРЫ" + "+ добавить" action;
   profile rows with **signal bars** on the right (compact, non-edit mode).
7. **Events panel** (`buildEventPanel(5)`) — section title "СОБЫТИЯ" + up to 5 event rows.
8. **Status panel** (`buildStatusPanel`) — a card with a human status line + a dim mono technical-details line.

---

## 2 · Profiles (`buildProfilesTab`) — TAB_PROFILES
1. **Title block**: "Профили" (24sp bold) + subtitle "Сохранённые olcRTC/MTS Link конфигурации".
2. **Profiles panel** (`buildProfilesPanel(true)`) — section title "ПРОФИЛИ"; rows show an
   **"изменить"** text-action instead of signal bars (full/edit mode).
3. **Editor host** — populated by `openProfileEditor(selected, false)`:
   - Card titled "РЕДАКТОР ПРОФИЛЯ" (or "НОВЫЙ ПРОФИЛЬ") with an "удалить" action (hidden for new).
   - **Name input** (single line).
   - **URI input** (multiline, ≥6 lines, top-aligned) — `olcrtc://…`.
   - **"Сохранить профиль"** primary button.
- Tapping a row selects it (`selectProfile`) → active dot turns lime, KEY_LINK persisted.
- "+ добавить" / row "изменить" both open the editor focused.

## Intent flow (deep link)
`handleIncomingIntent` — an external `olcrtc://…` link switches to Profiles tab and opens the
editor pre-filled with the incoming URI; status "Ссылка получена. Сохрани её как профиль."

---

## 3 · Traffic (`buildTrafficTab`) — TAB_TRAFFIC
1. **Title block**: "Трафик ≈" + a subtitle warning that figures are approximate (TrafficStats
   includes app background traffic). The `≈` in the title is intentional honesty.
2. **Metrics 2×2** — the SAME `buildMetricsGrid` component as Home.
3. **Session summary** (`buildTrafficSummary`) — card, section "СЕССИЯ": Принято / Отправлено / Транспорт.
4. **Events panel** (`buildEventPanel(12)`) — same component, limit raised to 12.

---

## 4 · Settings (`buildSettingsTab` → `buildSettingsForm`) — TAB_SETTINGS
Title "Настройки" + subtitle. Then a **transport-aware form** bound to the SELECTED profile:
- If no profile → message + "Открыть профили" button.
- If URI won't parse → message + "Редактировать URI" button.
- Otherwise a card titled with the profile name + a sub-line `carrier / transport / lanes=N`, then
  conditionally-rendered fields (each = mono dim label + text input, input bg `surface_input`,
  radius 12dp):

| Field | Shown when |
|---|---|
| MTU | always |
| SEI/VP8 FPS, SEI/VP8 batch | transport is SEI **or** VP8 |
| Fragment bytes, SEI ACK ms | SEI |
| Multipath lanes, Control lanes, Connect parallelism, Min ready lanes, Max streams/lane, Traffic max payload, Traffic min/max delay | SEI **and** carrier == mtslink |
| Liveness interval / timeout / failures | carrier == mtslink (any transport) |

- **"Сохранить параметры"** primary → rewrites only the edited params back into the URI
  (`rewriteParams`, empty fields are removed). **"Открыть полный URI"** secondary → jumps to editor.
- This conditional rendering is the most mature part of the IA: VP8 never shows SEI-only ACK,
  non-mtslink never shows multipath, and saving never injects irrelevant params into the URI.

---

## Connection state machine
`STATE_DISCONNECTED / CONNECTING / CONNECTED` (`applyConnectionState`). Status text from the
foreground `OlcVpnService` broadcast is normalised (`compactStatus` → human RU strings) and mapped
to state (`updateStateFromStatus`). The button label, status dot color, badge text, signal-bar
level, and metric deltas all read from this state + the latest telemetry extras
(rxBps, txBps, probeLatencyMs, uptimeMs, lanes, carrier, transport).
