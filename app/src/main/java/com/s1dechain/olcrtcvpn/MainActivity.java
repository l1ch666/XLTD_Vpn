package com.s1dechain.olcrtcvpn;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.InputType;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class MainActivity extends Activity {
    private static final int VPN_REQUEST_CODE = 1201;
    private static final String PREFS = "main";
    private static final String KEY_LINK = "last_link";
    private static final String KEY_PROFILE_IDS = "profile_ids";
    private static final String KEY_SELECTED_PROFILE_ID = "selected_profile_id";

    private static final int TAB_HOME = 0;
    private static final int TAB_PROFILES = 1;
    private static final int TAB_TRAFFIC = 2;
    private static final int TAB_SETTINGS = 3;

    private static final int STATE_DISCONNECTED = 0;
    private static final int STATE_CONNECTING = 1;
    private static final int STATE_CONNECTED = 2;

    // Palette: one source of truth for the dark-violet theme. Update here
    // to retheme the whole UI; avoid scattering Color.parseColor("...") literals.
    private static final int COLOR_BG = 0xFF13121A;          // v2: deeper violet-black per design
    private static final int COLOR_SURFACE_DARK = 0xFF1A1928; // v2: violet-tinted card surface
    private static final int COLOR_SURFACE_LINE = 0xFF2A2A38;
    private static final int COLOR_BORDER_DIM = 0xFF3E3E50;
    private static final int COLOR_BORDER = 0xFF444456;
    private static final int COLOR_TEXT_MUTED = 0xFF55556A;
    private static final int COLOR_TEXT_DIM = 0xFF66667A;
    private static final int COLOR_TEXT_LABEL = 0xFF7E7E92;
    private static final int COLOR_TEXT_SECONDARY = 0xFFCCCCD8;
    private static final int COLOR_TEXT_TERTIARY = 0xFFCFCFDB;
    private static final int COLOR_TEXT_BRIGHT = 0xFFE7E7F0;
    private static final int COLOR_TEXT = 0xFFF0F0F8;
    private static final int COLOR_PRIMARY = 0xFF6C5CE7;
    private static final int COLOR_PRIMARY_LIGHT = 0xFFA89FF5;
    private static final int COLOR_PRIMARY_PALE = 0xFFD7D2FF;
    private static final int COLOR_PRIMARY_DEEP = 0xFF5B4FD6;
    private static final int COLOR_SEI = 0xFF00D2FF;
    private static final int COLOR_VP8 = 0xFFE17055;
    private static final int COLOR_VIDEO = 0xFF5B8CFF;

    private LinearLayout content;
    private LinearLayout bottomNav;
    private View homeNav;
    private View profilesNav;
    private View trafficNav;
    private View settingsNav;

    private TextView statusBadge;
    private TextView statusDot;
    private TextView sessionAmount;   // hero: speed value e.g. "1.84"
    private TextView sessionUnit;     // hero: unit + direction e.g. "↓  MB/s"
    private TextView sessionSub;      // hero: context line "mtslink · SEI · 12 lanes · 74 ms"
    private TextView sessionPill;     // hero: session pill "Сессия 12.4 MB · 0:42"
    private TextView toggleButton;
    private LinearLayout chipBar;
    private TextView rxValue;
    private TextView txValue;
    private TextView latencyValue;
    private TextView uptimeValue;
    private TextView rxDelta;
    private TextView txDelta;
    private LinearLayout profileCards;
    private LinearLayout eventLog;
    private TextView statusView;
    private TextView detailsView;
    private boolean profileCardsFull = false;

    private EditText profileNameInput;
    private EditText linkInput;
    private LinearLayout editorHost;
    private TextView editorTitle;
    private TextView editorDeleteButton;

    private EditText mtuInput;
    private EditText fpsInput;
    private EditText batchInput;
    private EditText fragInput;
    private EditText ackInput;
    private EditText lanesInput;
    private EditText controlLanesInput;
    private EditText connectParallelInput;
    private EditText minReadyInput;
    private EditText maxStreamsInput;
    private EditText trafficPayloadInput;
    private EditText trafficMinDelayInput;
    private EditText trafficMaxDelayInput;
    private EditText liveIntervalInput;
    private EditText liveTimeoutInput;
    private EditText liveFailuresInput;

    private String pendingLink;
    private String selectedProfileId;
    private String editingProfileId;
    private int activeTab = TAB_HOME;
    private int connectionState = STATE_DISCONNECTED;
    private boolean statusReceiverRegistered = false;

    private String telemetryState = "disconnected";
    private String telemetryCarrier = "";
    private String telemetryTransport = "";
    private int telemetryLanes = 1;
    private long uptimeMs = 0L;
    private long sessionRxBytes = 0L;
    private long sessionTxBytes = 0L;
    private long rxBps = 0L;
    private long txBps = 0L;
    private long probeLatencyMs = -1L;

    private final List<String> recentEvents = new ArrayList<>();

    private final BroadcastReceiver statusReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (!OlcVpnService.ACTION_STATUS.equals(intent.getAction())) return;
            String status = intent.getStringExtra(OlcVpnService.EXTRA_STATUS);
            telemetryState = intent.getStringExtra(OlcVpnService.EXTRA_STATE);
            if (telemetryState == null) telemetryState = "";
            telemetryCarrier = safe(intent.getStringExtra(OlcVpnService.EXTRA_CARRIER));
            telemetryTransport = safe(intent.getStringExtra(OlcVpnService.EXTRA_TRANSPORT));
            telemetryLanes = Math.max(1, intent.getIntExtra(OlcVpnService.EXTRA_LANES, 1));
            uptimeMs = intent.getLongExtra(OlcVpnService.EXTRA_UPTIME_MS, uptimeMs);
            sessionRxBytes = intent.getLongExtra(OlcVpnService.EXTRA_SESSION_RX_BYTES, sessionRxBytes);
            sessionTxBytes = intent.getLongExtra(OlcVpnService.EXTRA_SESSION_TX_BYTES, sessionTxBytes);
            rxBps = intent.getLongExtra(OlcVpnService.EXTRA_RX_BPS, rxBps);
            txBps = intent.getLongExtra(OlcVpnService.EXTRA_TX_BPS, txBps);
            probeLatencyMs = intent.getLongExtra(OlcVpnService.EXTRA_PROBE_LATENCY_MS, probeLatencyMs);
            if (status != null) applyServiceStatus(status);
            refreshDynamicUi();
        }
    };

    private static final class Profile {
        final String id;
        final String name;
        final String link;
        final String carrier;
        final String transport;

        Profile(String id, String name, String link, String carrier, String transport) {
            this.id = id;
            this.name = name;
            this.link = link;
            this.carrier = carrier;
            this.transport = transport;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        selectedProfileId = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_SELECTED_PROFILE_ID, "");
        buildUi();
        handleIncomingIntent(getIntent());
    }

    @Override
    protected void onStart() {
        super.onStart();
        registerStatusReceiver();
        String lastStatus = OlcVpnService.getLastStatusSnapshot();
        if (!TextUtils.isEmpty(lastStatus)) applyServiceStatus(lastStatus);
        renderActiveTab();
    }

    @Override
    protected void onStop() {
        unregisterStatusReceiver();
        super.onStop();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIncomingIntent(intent);
    }

    private void registerStatusReceiver() {
        if (statusReceiverRegistered) return;
        IntentFilter filter = new IntentFilter(OlcVpnService.ACTION_STATUS);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(statusReceiver, filter);
        }
        statusReceiverRegistered = true;
    }

    private void unregisterStatusReceiver() {
        if (!statusReceiverRegistered) return;
        try {
            unregisterReceiver(statusReceiver);
        } catch (Exception ignored) {
        } finally {
            statusReceiverRegistered = false;
        }
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(COLOR_BG);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(false);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(18), dp(10), dp(18), dp(10));
        scroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
        ));

        bottomNav = new LinearLayout(this);
        bottomNav.setOrientation(LinearLayout.HORIZONTAL);
        bottomNav.setPadding(dp(10), dp(8), dp(10), dp(10));
        // Use the same dark-violet background as the screen, with a hairline top border
        bottomNav.setBackground(roundedDrawable("#13121A", 0, "#2A2A3E", 1));
        root.addView(bottomNav, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        setContentView(root);
        renderBottomNav();
        renderActiveTab();

        boolean comboReady = OlcMobileBridge.isAvailable() && Tun2SocksMobileBridge.isAvailable();
        setStatus(comboReady ? "Готов к подключению." : "Core не найден. Собери combo AAR и пересобери APK.");
        applyConnectionState(STATE_DISCONNECTED, comboReady ? "Готов" : "Нет core");
    }

    private void renderActiveTab() {
        if (content == null) return;
        content.removeAllViews();
        editorHost = null;
        profileCards = null;
        eventLog = null;
        statusView = null;
        detailsView = null;
        sessionPill = null;
        mtuInput = null;
        fpsInput = null;
        batchInput = null;
        fragInput = null;
        ackInput = null;
        lanesInput = null;
        controlLanesInput = null;
        connectParallelInput = null;
        minReadyInput = null;
        maxStreamsInput = null;
        trafficPayloadInput = null;
        trafficMinDelayInput = null;
        trafficMaxDelayInput = null;
        liveIntervalInput = null;
        liveTimeoutInput = null;
        liveFailuresInput = null;

        if (activeTab == TAB_HOME) {
            buildHomeTab();
        } else if (activeTab == TAB_PROFILES) {
            buildProfilesTab();
        } else if (activeTab == TAB_TRAFFIC) {
            buildTrafficTab();
        } else {
            buildSettingsTab();
        }
        renderBottomNav();
        refreshDynamicUi();
    }

    private void buildHomeTab() {
        content.addView(buildStatusBar(), lpMatchWrapNoMargin());
        content.addView(buildHero(), lpMatchWrapNoMargin());
        content.addView(buildConnectButton(), lpMatchWrapNoMargin());
        content.addView(buildTransportChips(), lpMatchWrapNoMargin());
        content.addView(buildMetricsGrid(), lpMatchWrapNoMargin());
        content.addView(buildProfilesPanel(false), lpMatchWrap());
        content.addView(buildEventPanel(5), lpMatchWrap());
        content.addView(buildStatusPanel(), lpMatchWrap());
    }

    private void buildProfilesTab() {
        content.addView(titleBlock("Профили", "Сохранённые olcRTC/MTS Link конфигурации"), lpMatchWrapNoMargin());
        content.addView(buildProfilesPanel(true), lpMatchWrap());
        editorHost = new LinearLayout(this);
        editorHost.setOrientation(LinearLayout.VERTICAL);
        content.addView(editorHost, lpMatchWrap());
        openProfileEditor(getSelectedProfile(), false);
    }

    private void buildTrafficTab() {
        content.addView(titleBlock("Трафик ≈", "Скорость считается через TrafficStats и включает фоновый трафик приложения (зонды, DNS, HTTP-пинги), поэтому значения приблизительные."), lpMatchWrapNoMargin());
        content.addView(buildMetricsGrid(), lpMatchWrapNoMargin());
        content.addView(buildTrafficSummary(), lpMatchWrap());
        content.addView(buildEventPanel(12), lpMatchWrap());
    }

    private void buildSettingsTab() {
        content.addView(titleBlock("Настройки", "Параметры выбранного профиля без смены формата хранения"), lpMatchWrapNoMargin());
        content.addView(buildSettingsForm(), lpMatchWrap());
    }

    private LinearLayout buildStatusBar() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(0, dp(4), 0, dp(8));

        TextView app = smallMono("XLTD VPN");
        app.setTextColor(COLOR_TEXT_MUTED);
        row.addView(app, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        TextView speed = smallMono("↓ " + formatRate(rxBps));
        speed.setTextColor(COLOR_TEXT_DIM);
        row.addView(speed, lpWrapWrapNoMargin());
        return row;
    }

    private LinearLayout buildHero() {
        LinearLayout hero = new LinearLayout(this);
        hero.setOrientation(LinearLayout.VERTICAL);
        hero.setGravity(Gravity.CENTER_HORIZONTAL);
        hero.setPadding(0, dp(12), 0, dp(10));

        // ── Status badge: dot + connection state label ──────────────────────
        LinearLayout badge = new LinearLayout(this);
        badge.setOrientation(LinearLayout.HORIZONTAL);
        badge.setGravity(Gravity.CENTER_VERTICAL);
        badge.setPadding(dp(9), dp(5), dp(12), dp(5));
        badge.setBackground(roundedDrawable("#1C1B2A", 20, "#2A2A3E", 1));

        statusDot = new TextView(this);
        statusDot.setText(" ");
        statusDot.setBackground(roundedDrawable("#444452", 8, null, 0));
        LinearLayout.LayoutParams dotLp = new LinearLayout.LayoutParams(dp(8), dp(8));
        dotLp.setMargins(0, 0, dp(7), 0);
        badge.addView(statusDot, dotLp);

        statusBadge = new TextView(this);
        statusBadge.setTextColor(COLOR_TEXT_LABEL);
        statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        statusBadge.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL));
        badge.addView(statusBadge, lpWrapWrapNoMargin());
        hero.addView(badge, lpWrapWrapNoMargin());

        // ── Speed hero: "↓" arrow + large number + unit ────────────────────
        // Design spec: "↓ 1.84 MB/s" as primary metric — speed is more
        // informative than accumulated bytes while actively connected.
        LinearLayout speedRow = new LinearLayout(this);
        speedRow.setGravity(Gravity.CENTER | Gravity.BOTTOM);
        speedRow.setPadding(0, dp(14), 0, 0);

        // Direction arrow (muted, baseline-aligned with unit, not the number)
        TextView arrowLabel = new TextView(this);
        arrowLabel.setText("↓");
        arrowLabel.setTextColor(COLOR_TEXT_MUTED);
        arrowLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        arrowLabel.setTypeface(Typeface.MONOSPACE);
        arrowLabel.setIncludeFontPadding(false);
        LinearLayout.LayoutParams arrowLp = lpWrapWrapNoMargin();
        arrowLp.setMargins(0, 0, dp(5), dp(6));
        speedRow.addView(arrowLabel, arrowLp);

        // Speed value: the big number (font weight via MONOSPACE for crisp digits)
        sessionAmount = new TextView(this);
        sessionAmount.setTextColor(COLOR_TEXT);
        sessionAmount.setTextSize(TypedValue.COMPLEX_UNIT_SP, 52);
        sessionAmount.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        sessionAmount.setIncludeFontPadding(false);
        speedRow.addView(sessionAmount, lpWrapWrapNoMargin());

        // Unit label (e.g. "MB/s"), baseline aligned beside the number
        sessionUnit = new TextView(this);
        sessionUnit.setTextColor(COLOR_TEXT_DIM);
        sessionUnit.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        sessionUnit.setTypeface(Typeface.MONOSPACE);
        sessionUnit.setIncludeFontPadding(false);
        LinearLayout.LayoutParams unitLp = lpWrapWrapNoMargin();
        unitLp.setMargins(dp(6), 0, 0, dp(8));
        speedRow.addView(sessionUnit, unitLp);
        hero.addView(speedRow, lpWrapWrapNoMargin());

        // ── Context line: "mtslink · SEI · 12 lanes · 74 ms" ──────────────
        sessionSub = new TextView(this);
        sessionSub.setTextColor(COLOR_TEXT_DIM);
        sessionSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        sessionSub.setTypeface(Typeface.SANS_SERIF);
        LinearLayout.LayoutParams ctxLp = lpWrapWrapNoMargin();
        ctxLp.setMargins(0, dp(3), 0, 0);
        hero.addView(sessionSub, ctxLp);

        // ── Session pill: "Сессия 12.4 MB · 0:42" ─────────────────────────
        sessionPill = new TextView(this);
        sessionPill.setTextColor(COLOR_TEXT_MUTED);
        sessionPill.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        sessionPill.setTypeface(Typeface.SANS_SERIF);
        sessionPill.setPadding(dp(10), dp(4), dp(10), dp(4));
        sessionPill.setBackground(roundedDrawable("#1C1B2A", 12, "#2A2A3E", 1));
        LinearLayout.LayoutParams pillLp = lpWrapWrapNoMargin();
        pillLp.setMargins(0, dp(8), 0, 0);
        hero.addView(sessionPill, pillLp);
        return hero;
    }

    private View buildConnectButton() {
        LinearLayout wrap = new LinearLayout(this);
        wrap.setPadding(0, 0, 0, dp(12));
        toggleButton = new TextView(this);
        toggleButton.setGravity(Gravity.CENTER);
        toggleButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        toggleButton.setTypeface(Typeface.DEFAULT_BOLD);
        toggleButton.setPadding(dp(16), dp(15), dp(16), dp(15));
        toggleButton.setClickable(true);
        toggleButton.setOnClickListener(v -> onToggleClick());
        wrap.addView(toggleButton, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        return wrap;
    }

    private LinearLayout buildTransportChips() {
        chipBar = new LinearLayout(this);
        chipBar.setOrientation(LinearLayout.HORIZONTAL);
        chipBar.setGravity(Gravity.CENTER);
        chipBar.setPadding(0, 0, 0, dp(12));
        addTransportChip("SEI", OlcUriParser.TRANSPORT_SEI);
        addTransportChip("VP8", OlcUriParser.TRANSPORT_VP8);
        addTransportChip("Data", OlcUriParser.TRANSPORT_DATA);
        addTransportChip("Video", OlcUriParser.TRANSPORT_VIDEO);
        return chipBar;
    }

    private void addTransportChip(String label, String transport) {
        LinearLayout chip = new LinearLayout(this);
        chip.setOrientation(LinearLayout.HORIZONTAL);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dp(10), dp(6), dp(10), dp(6));
        chip.setClickable(true);
        chip.setFocusable(true);
        chip.setTag(transport);
        chip.setOnClickListener(v -> {
            String target = (String) v.getTag();
            if (target == null || target.isEmpty()) return;
            switchSelectedTransport(target);
        });

        View dot = new View(this);
        dot.setTag("dot");
        LinearLayout.LayoutParams dotLp = new LinearLayout.LayoutParams(dp(6), dp(6));
        dotLp.setMargins(0, 0, dp(5), 0);
        chip.addView(dot, dotLp);

        TextView text = new TextView(this);
        text.setTag("label");
        text.setText(label);
        text.setGravity(Gravity.CENTER);
        text.setIncludeFontPadding(false);
        text.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        chip.addView(text, lpWrapWrapNoMargin());

        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        lp.setMargins(dp(3), 0, dp(3), 0);
        chipBar.addView(chip, lp);
    }

    private LinearLayout buildMetricsGrid() {
        LinearLayout grid = new LinearLayout(this);
        grid.setOrientation(LinearLayout.VERTICAL);
        grid.setPadding(0, 0, 0, dp(4));

        LinearLayout row1 = new LinearLayout(this);
        row1.setOrientation(LinearLayout.HORIZONTAL);
        rxValue = metricValue(row1, "↓ ВХОДЯЩИЙ", "0 KB/s", "ожидание");
        txValue = metricValue(row1, "↑ ИСХОДЯЩИЙ", "0 KB/s", "ожидание");
        grid.addView(row1, lpMatchWrapNoMargin());

        LinearLayout row2 = new LinearLayout(this);
        row2.setOrientation(LinearLayout.HORIZONTAL);
        latencyValue = metricValue(row2, "ЗАДЕРЖКА", "— ms", "SOCKS probe");
        uptimeValue = metricValue(row2, "АПТАЙМ", "0:00", "сессия");
        grid.addView(row2, lpMatchWrapNoMargin());
        return grid;
    }

    private TextView metricValue(LinearLayout row, String label, String value, String delta) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(12), dp(10), dp(12), dp(10));
        card.setBackground(roundedDrawable("#1A1928", 12, "#2A2A3E", 1));

        TextView l = smallMono(label);
        l.setTextColor(COLOR_TEXT_MUTED);
        card.addView(l, lpMatchWrapNoMargin());

        TextView v = new TextView(this);
        v.setText(value);
        v.setTextColor(COLOR_TEXT);
        v.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        v.setTypeface(Typeface.MONOSPACE);
        v.setPadding(0, dp(3), 0, 0);
        card.addView(v, lpMatchWrapNoMargin());

        TextView d = smallMono(delta);
        d.setTextColor(COLOR_PRIMARY);
        d.setPadding(0, dp(2), 0, 0);
        card.addView(d, lpMatchWrapNoMargin());
        if (rxValue == null) rxDelta = d;
        else if (txValue == null) txDelta = d;

        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        lp.setMargins(dp(4), dp(4), dp(4), dp(4));
        row.addView(card, lp);
        return v;
    }

    private LinearLayout buildProfilesPanel(boolean full) {
        LinearLayout card = card();
        profileCardsFull = full;
        LinearLayout header = row();
        TextView title = sectionTitle(full ? "ПРОФИЛИ" : "СЕРВЕРЫ");
        header.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView add = smallAction("+ добавить");
        add.setOnClickListener(v -> {
            activeTab = TAB_PROFILES;
            renderActiveTab();
            openProfileEditor(null, true);
        });
        header.addView(add, lpWrapWrapNoMargin());
        card.addView(header, lpMatchWrapNoMargin());

        profileCards = new LinearLayout(this);
        profileCards.setOrientation(LinearLayout.VERTICAL);
        profileCards.setPadding(0, dp(8), 0, 0);
        card.addView(profileCards, lpMatchWrapNoMargin());
        refreshProfiles();
        return card;
    }

    private LinearLayout buildEventPanel(int limit) {
        LinearLayout wrap = new LinearLayout(this);
        wrap.setOrientation(LinearLayout.VERTICAL);
        wrap.setPadding(0, dp(2), 0, dp(2));
        TextView title = sectionTitle("СОБЫТИЯ");
        wrap.addView(title, lpMatchWrapNoMargin());
        eventLog = new LinearLayout(this);
        eventLog.setOrientation(LinearLayout.VERTICAL);
        eventLog.setTag(limit);
        eventLog.setPadding(0, dp(7), 0, 0);
        wrap.addView(eventLog, lpMatchWrapNoMargin());
        refreshEvents();
        return wrap;
    }

    private LinearLayout buildStatusPanel() {
        LinearLayout card = card();
        statusView = bodyText("Готов.");
        card.addView(statusView, lpMatchWrapNoMargin());
        detailsView = smallMono("Технические детали появятся после запуска.");
        detailsView.setTextColor(COLOR_TEXT_DIM);
        detailsView.setPadding(0, dp(8), 0, 0);
        card.addView(detailsView, lpMatchWrapNoMargin());
        return card;
    }

    private LinearLayout buildTrafficSummary() {
        LinearLayout card = card();
        card.addView(sectionTitle("СЕССИЯ"), lpMatchWrapNoMargin());
        TextView body = bodyText("Принято: " + formatBytes(sessionRxBytes) + "\nОтправлено: " + formatBytes(sessionTxBytes) + "\nТранспорт: " + activeTransportLabel());
        body.setPadding(0, dp(8), 0, 0);
        card.addView(body, lpMatchWrapNoMargin());
        return card;
    }

    private LinearLayout buildSettingsForm() {
        LinearLayout card = card();
        Profile selected = getSelectedProfile();
        if (selected == null) {
            card.addView(bodyText("Выбери профиль, чтобы редактировать параметры транспорта."), lpMatchWrapNoMargin());
            TextView openProfiles = primarySmallButton("Открыть профили");
            openProfiles.setOnClickListener(v -> {
                activeTab = TAB_PROFILES;
                renderActiveTab();
            });
            card.addView(openProfiles, lpMatchWrap());
            return card;
        }

        OlcConfig config;
        try {
            config = OlcUriParser.parse(selected.link);
        } catch (Exception e) {
            card.addView(bodyText("Ссылка нестандартная, открыл обычный редактор."), lpMatchWrapNoMargin());
            TextView edit = primarySmallButton("Редактировать URI");
            edit.setOnClickListener(v -> {
                activeTab = TAB_PROFILES;
                renderActiveTab();
                openProfileEditor(selected, true);
            });
            card.addView(edit, lpMatchWrap());
            return card;
        }

        card.addView(sectionTitle(selected.name), lpMatchWrapNoMargin());
        card.addView(smallText(config.carrier + " / " + config.transport + " / lanes=" + lanesFor(config)), lpMatchWrap());

        boolean isSei = OlcUriParser.TRANSPORT_SEI.equalsIgnoreCase(config.transport);
        boolean isVp8 = OlcUriParser.TRANSPORT_VP8.equalsIgnoreCase(config.transport);
        boolean isMtsLink = "mtslink".equalsIgnoreCase(config.carrier);

        // Always: MTU + liveness (apply to every transport on every carrier).
        mtuInput = settingInput(card, "MTU", config.param("mtu", ""));

        if (isSei || isVp8) {
            // FPS / batch labels make sense only for SEI and legacy VP8.
            fpsInput = settingInput(card, isSei ? "SEI FPS" : "VP8 FPS",
                    config.param("fps", config.param(isSei ? "sei-fps" : "vp8-fps", isSei ? "30" : "25")));
            batchInput = settingInput(card, isSei ? "SEI batch" : "VP8 batch",
                    config.param("batch", config.param(isSei ? "sei-batch" : "vp8-batch", isSei ? "8" : "1")));
        }

        if (isSei) {
            fragInput = settingInput(card, "Fragment bytes", config.param("frag", config.param("sei-frag", "700")));
            ackInput = settingInput(card, "SEI ACK ms", config.param("sei-ack-ms", config.param("ack-ms", "10000")));
            if (isMtsLink) {
                // Multipath lanes are mtslink+SEI specific.
                lanesInput = settingInput(card, "Multipath lanes", config.param("mc-lanes", config.param("sei-lanes", config.param("lanes", "12"))));
                controlLanesInput = settingInput(card, "Control lanes", config.param("mc-control-lanes", "1"));
                connectParallelInput = settingInput(card, "Connect parallelism", config.param("mc-connect-parallel", config.param("mc-connect-parallelism", "2")));
                minReadyInput = settingInput(card, "Minimum ready lanes", config.param("mc-min-ready", "4"));
                maxStreamsInput = settingInput(card, "Max streams per lane", config.param("mc-max-streams-per-lane", "3"));
                trafficPayloadInput = settingInput(card, "Traffic max payload", config.param("traffic-max-payload", config.param("traffic-max-payload-size", "5600")));
                trafficMinDelayInput = settingInput(card, "Traffic min delay", config.param("traffic-min-delay", "4ms"));
                trafficMaxDelayInput = settingInput(card, "Traffic max delay", config.param("traffic-max-delay", "18ms"));
            }
        }

        if (isMtsLink) {
            // Liveness applies to every mtslink transport (control channel).
            liveIntervalInput = settingInput(card, "Liveness interval", config.param("liveness-interval", "20s"));
            liveTimeoutInput = settingInput(card, "Liveness timeout", config.param("liveness-timeout", "60s"));
            liveFailuresInput = settingInput(card, "Liveness failures", config.param("liveness-failures", "3"));
        }

        TextView save = primarySmallButton("Сохранить параметры");
        save.setOnClickListener(v -> saveSettings(selected));
        card.addView(save, lpMatchWrap());

        TextView edit = secondarySmallButton("Открыть полный URI");
        edit.setOnClickListener(v -> {
            activeTab = TAB_PROFILES;
            renderActiveTab();
            openProfileEditor(selected, true);
        });
        card.addView(edit, lpMatchWrapNoMargin());
        return card;
    }

    private EditText settingInput(LinearLayout parent, String label, String value) {
        TextView l = smallMono(label);
        l.setTextColor(COLOR_TEXT_DIM);
        parent.addView(l, lpMatchWrapNoMargin());
        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setText(value == null ? "" : value);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        input.setTextColor(COLOR_TEXT);
        input.setHintTextColor(COLOR_TEXT_MUTED);
        input.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        input.setPadding(dp(12), dp(10), dp(12), dp(10));
        input.setBackground(roundedDrawable("#13121A", 12, "#2A2A3E", 1));
        parent.addView(input, lpMatchWrap());
        return input;
    }

    private LinearLayout titleBlock(String title, String subtitle) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(0, dp(8), 0, dp(12));
        TextView t = new TextView(this);
        t.setText(title);
        t.setTextColor(COLOR_TEXT);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        box.addView(t, lpMatchWrapNoMargin());
        TextView s = bodyText(subtitle);
        s.setTextColor(COLOR_TEXT_DIM);
        box.addView(s, lpMatchWrapNoMargin());
        return box;
    }

    private void renderBottomNav() {
        if (bottomNav == null) return;
        bottomNav.removeAllViews();
        homeNav = navItem("Главная", TAB_HOME, NavIconView.ICON_HOME);
        profilesNav = navItem("Профили", TAB_PROFILES, NavIconView.ICON_PROFILES);
        trafficNav = navItem("Трафик", TAB_TRAFFIC, NavIconView.ICON_TRAFFIC);
        settingsNav = navItem("Настройки", TAB_SETTINGS, NavIconView.ICON_SETTINGS);
        bottomNav.addView(homeNav, navLp());
        bottomNav.addView(profilesNav, navLp());
        bottomNav.addView(trafficNav, navLp());
        bottomNav.addView(settingsNav, navLp());
    }

    private LinearLayout navItem(String label, int tab, int iconType) {
        boolean active = (tab == activeTab);
        int color = active ? COLOR_PRIMARY : COLOR_BORDER;

        LinearLayout item = new LinearLayout(this);
        item.setOrientation(LinearLayout.VERTICAL);
        item.setGravity(Gravity.CENTER);
        item.setPadding(dp(4), dp(8), dp(4), dp(8));
        item.setClickable(true);
        item.setFocusable(true);
        item.setOnClickListener(v -> {
            activeTab = tab;
            renderActiveTab();
        });

        // SVG-style line icon (1.5 dp stroke, rounded caps) — design spec v2
        NavIconView icon = new NavIconView(this);
        icon.setIconType(iconType);
        icon.setColor(color);
        LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(dp(22), dp(20));
        iconLp.setMargins(0, 0, 0, dp(3));
        item.addView(icon, iconLp);

        TextView text = new TextView(this);
        text.setText(label.toUpperCase(Locale.ROOT));
        text.setGravity(Gravity.CENTER);
        text.setTextSize(TypedValue.COMPLEX_UNIT_SP, 8);
        text.setTypeface(Typeface.DEFAULT_BOLD);
        text.setTextColor(color);
        text.setIncludeFontPadding(false);
        item.addView(text, lpWrapWrapNoMargin());
        return item;
    }

    private void refreshDynamicUi() {
        applyConnectionState(connectionState, null);
        if (statusBadge != null) statusBadge.setText(statusBadgeText());
        if (statusDot != null) statusDot.setBackground(roundedDrawable(statusDotColor(), 8, null, 0));
        // Hero: show download speed as the primary metric (design v2)
        if (sessionAmount != null) {
            ByteLabel speed = formatSpeedHero(rxBps);
            sessionAmount.setText(speed.value);
            if (sessionUnit != null) sessionUnit.setText(speed.unit);
        }
        if (sessionSub != null) sessionSub.setText(heroContextLine());
        if (sessionPill != null) sessionPill.setText(sessionPillText());
        if (rxValue != null) rxValue.setText(formatRate(rxBps));
        if (txValue != null) txValue.setText(formatRate(txBps));
        if (latencyValue != null) latencyValue.setText(probeLatencyMs >= 0 ? probeLatencyMs + " ms" : "— ms");
        if (uptimeValue != null) uptimeValue.setText(formatUptime(uptimeMs));
        if (rxDelta != null) rxDelta.setText(activeTransportLabel());
        if (txDelta != null) txDelta.setText(telemetryLanes > 1 ? "SEI · " + telemetryLanes + " lanes" : "один канал");
        refreshTransportChips();
        refreshProfiles();
        refreshEvents();
    }

    private void refreshTransportChips() {
        if (chipBar == null) return;
        Profile selected = getSelectedProfile();
        String active = selected == null ? telemetryTransport : selected.transport;
        for (int i = 0; i < chipBar.getChildCount(); i++) {
            View child = chipBar.getChildAt(i);
            String transport = String.valueOf(child.getTag());
            boolean on = transport.equals(active);
            child.setBackground(roundedDrawable(on ? "#221F38" : "#1A1928", 20, on ? "#6C5CE7" : "#2A2A3E", 1));
            if (child instanceof ViewGroup) {
                ViewGroup group = (ViewGroup) child;
                for (int j = 0; j < group.getChildCount(); j++) {
                    View inner = group.getChildAt(j);
                    Object tag = inner.getTag();
                    if ("dot".equals(tag)) {
                        inner.setBackground(roundedDrawable(on ? colorHex(transportAccent(transport)) : "#444452", 6, null, 0));
                    } else if ("label".equals(tag) && inner instanceof TextView) {
                        ((TextView) inner).setTextColor(on ? COLOR_PRIMARY_PALE : COLOR_TEXT_DIM);
                    }
                }
            }
        }
    }

    private void refreshProfiles() {
        if (profileCards == null) return;
        profileCards.removeAllViews();
        List<Profile> profiles = loadProfiles();
        if (profiles.isEmpty()) {
            profileCards.addView(bodyText("Профилей пока нет."), lpMatchWrapNoMargin());
            return;
        }
        for (Profile profile : profiles) {
            profileCards.addView(profileRow(profile), lpMatchWrap());
        }
    }

    private LinearLayout profileRow(Profile profile) {
        boolean selected = profile.id.equals(selectedProfileId);
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), dp(9), dp(10), dp(9));
        row.setBackground(roundedDrawable("#1A1928", 14, selected ? "#38384E" : "#2A2A3E", 1));
        row.setOnClickListener(v -> selectProfile(profile));

        TextView active = new TextView(this);
        active.setText(" ");
        active.setBackground(roundedDrawable(selected ? "#00D2FF" : "#2A2A38", 7, null, 0));
        LinearLayout.LayoutParams dotLp = new LinearLayout.LayoutParams(dp(7), dp(7));
        dotLp.setMargins(0, 0, dp(10), 0);
        row.addView(active, dotLp);

        TextView icon = new TextView(this);
        icon.setGravity(Gravity.CENTER);
        icon.setText(profileIcon(profile));
        icon.setTextColor(COLOR_PRIMARY_LIGHT);
        icon.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        icon.setIncludeFontPadding(false);
        icon.setBackground(roundedDrawable("#1C1B2A", 10, null, 0));
        LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(dp(32), dp(32));
        iconLp.setMargins(0, 0, dp(10), 0);
        row.addView(icon, iconLp);

        LinearLayout text = new LinearLayout(this);
        text.setOrientation(LinearLayout.VERTICAL);
        TextView name = bodyText(profileTitle(profile));
        name.setTextColor(COLOR_TEXT_SECONDARY);
        name.setTypeface(Typeface.DEFAULT_BOLD);
        text.addView(name, lpMatchWrapNoMargin());
        TextView meta = smallText(profileMeta(profile));
        text.addView(meta, lpMatchWrapNoMargin());
        row.addView(text, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        if (profileCardsFull) {
            TextView edit = smallAction("изменить");
            edit.setOnClickListener(v -> {
                activeTab = TAB_PROFILES;
                renderActiveTab();
                openProfileEditor(profile, true);
            });
            row.addView(edit, lpWrapWrapNoMargin());
        } else {
            SignalBarsView signal = new SignalBarsView(this);
            signal.setLevel(profileQualityLevel(profile));
            signal.setActive(selected);
            row.addView(signal, new LinearLayout.LayoutParams(dp(26), dp(24)));
        }
        return row;
    }

    private void refreshEvents() {
        if (eventLog == null) return;
        eventLog.removeAllViews();
        int limit = eventLog.getTag() instanceof Integer ? (Integer) eventLog.getTag() : 5;
        if (recentEvents.isEmpty()) {
            eventLog.addView(eventRow("WAIT", "События появятся после запуска."), lpMatchWrapNoMargin());
            return;
        }
        int count = Math.min(limit, recentEvents.size());
        for (int i = 0; i < count; i++) {
            eventLog.addView(eventRow(tagForEvent(recentEvents.get(i)), compactEvent(recentEvents.get(i))), lpMatchWrapNoMargin());
        }
    }

    private LinearLayout eventRow(String tag, String text) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.TOP);
        row.setPadding(0, dp(5), 0, dp(5));

        TextView time = smallMono(currentShortTime());
        time.setTextColor(COLOR_BORDER_DIM);
        row.addView(time, fixedWidth(dp(42)));

        TextView tagView = smallMono(tag);
        tagView.setTextColor(tagColor(tag));
        tagView.setGravity(Gravity.CENTER);
        tagView.setPadding(dp(5), dp(2), dp(5), dp(2));
        tagView.setBackground(roundedDrawable("#1C1B2A", 5, null, 0));
        LinearLayout.LayoutParams tagLp = lpWrapWrapNoMargin();
        tagLp.setMargins(0, 0, dp(8), 0);
        row.addView(tagView, tagLp);

        TextView msg = smallText(text);
        row.addView(msg, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        return row;
    }

    private void openProfileEditor(Profile profile, boolean focus) {
        if (editorHost == null) return;
        editorHost.removeAllViews();
        LinearLayout card = card();
        LinearLayout header = row();
        editorTitle = sectionTitle(profile == null ? "НОВЫЙ ПРОФИЛЬ" : "РЕДАКТОР ПРОФИЛЯ");
        header.addView(editorTitle, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        editorDeleteButton = smallAction("удалить");
        editorDeleteButton.setVisibility(profile == null ? View.GONE : View.VISIBLE);
        editorDeleteButton.setOnClickListener(v -> deleteEditingProfile());
        header.addView(editorDeleteButton, lpWrapWrapNoMargin());
        card.addView(header, lpMatchWrapNoMargin());

        editingProfileId = profile == null ? null : profile.id;
        profileNameInput = editText("Название профиля", false);
        profileNameInput.setText(profile == null ? "" : profile.name);
        card.addView(profileNameInput, lpMatchWrap());

        linkInput = editText("olcrtc://...", true);
        linkInput.setMinLines(6);
        linkInput.setGravity(Gravity.TOP | Gravity.START);
        linkInput.setText(profile == null ? "" : profile.link);
        card.addView(linkInput, lpMatchWrap());

        TextView save = primarySmallButton("Сохранить профиль");
        save.setOnClickListener(v -> saveEditorProfile());
        card.addView(save, lpMatchWrap());

        editorHost.addView(card, lpMatchWrapNoMargin());
        if (focus) linkInput.requestFocus();
    }

    private EditText editText(String hint, boolean multiline) {
        EditText edit = new EditText(this);
        edit.setHint(hint);
        edit.setTextColor(COLOR_TEXT);
        edit.setHintTextColor(COLOR_TEXT_MUTED);
        edit.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        edit.setPadding(dp(12), dp(12), dp(12), dp(12));
        edit.setBackground(roundedDrawable("#13121A", 12, "#2A2A3E", 1));
        edit.setInputType(multiline
                ? InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                : InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        return edit;
    }

    private void handleIncomingIntent(Intent intent) {
        if (intent == null || intent.getDataString() == null) return;
        activeTab = TAB_PROFILES;
        renderActiveTab();
        openProfileEditor(new Profile("", "", intent.getDataString(), "", ""), true);
        setStatus("Ссылка получена. Сохрани её как профиль.");
    }

    private void onToggleClick() {
        hideEditorFocus();
        if (connectionState == STATE_CONNECTED || connectionState == STATE_CONNECTING) stopVpn();
        else connect();
    }

    private void connect() {
        try {
            Profile selected = getSelectedProfile();
            String link = selected != null ? selected.link : getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_LINK, "");
            if (link == null || link.trim().isEmpty()) {
                activeTab = TAB_PROFILES;
                renderActiveTab();
                openProfileEditor(null, true);
                setStatus("Сначала добавь olcRTC-профиль.");
                applyConnectionState(STATE_DISCONNECTED, "Нет профиля");
                return;
            }
            OlcUriParser.parse(link);
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_LINK, link).apply();
            pendingLink = link;
            applyConnectionState(STATE_CONNECTING, "VPN permission");
            setStatus("Готовлю подключение.");
            Intent prepare = VpnService.prepare(this);
            if (prepare != null) startActivityForResult(prepare, VPN_REQUEST_CODE);
            else startVpn(link);
        } catch (Exception e) {
            applyConnectionState(STATE_DISCONNECTED, "Ошибка ссылки");
            setStatus(humanError("bad_link: " + e.getMessage()));
            setDetails("Parser error: " + safe(e.getMessage()));
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != VPN_REQUEST_CODE) return;
        if (resultCode == RESULT_OK && pendingLink != null) startVpn(pendingLink);
        else {
            applyConnectionState(STATE_DISCONNECTED, "Нет разрешения");
            setStatus("VPN-разрешение не выдано.");
        }
    }

    private void startVpn(String link) {
        Intent intent = new Intent(this, OlcVpnService.class);
        intent.setAction(OlcVpnService.ACTION_START);
        intent.putExtra(OlcVpnService.EXTRA_LINK, link);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent);
        else startService(intent);
        applyConnectionState(STATE_CONNECTING, "Подключение");
        setStatus("Подключаюсь...");
    }

    private void stopVpn() {
        Intent intent = new Intent(this, OlcVpnService.class);
        intent.setAction(OlcVpnService.ACTION_STOP);
        startService(intent);
        applyConnectionState(STATE_DISCONNECTED, "Отключено");
        setStatus("Отключаю VPN...");
    }

    private void switchSelectedTransport(String transport) {
        Profile selected = getSelectedProfile();
        if (selected == null) {
            activeTab = TAB_PROFILES;
            renderActiveTab();
            openProfileEditor(null, true);
            setStatus("Выбери профиль для смены транспорта.");
            return;
        }
        try {
            String rewritten = rewriteTransport(selected.link, transport);
            saveProfile(selected.id, selected.name, rewritten);
            selectedProfileId = selected.id;
            getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                    .putString(KEY_SELECTED_PROFILE_ID, selectedProfileId)
                    .putString(KEY_LINK, rewritten)
                    .apply();
            setStatus("Транспорт переключён: " + transport);
            renderActiveTab();
            if (connectionState != STATE_DISCONNECTED) {
                stopVpn();
                new Thread(() -> {
                    try { Thread.sleep(700); } catch (InterruptedException ignored) {}
                    runOnUiThread(this::connect);
                }, "transport-restart").start();
            }
        } catch (Exception e) {
            activeTab = TAB_PROFILES;
            renderActiveTab();
            openProfileEditor(selected, true);
            setStatus("Не смог безопасно переписать URI. Открыл обычный редактор.");
        }
    }

    private void saveSettings(Profile selected) {
        try {
            Map<String, String> edits = new LinkedHashMap<>();
            edits.put("mtu", text(mtuInput));
            edits.put("fps", text(fpsInput));
            edits.put("batch", text(batchInput));
            edits.put("frag", text(fragInput));
            edits.put("sei-ack-ms", text(ackInput));
            edits.put("mc-lanes", text(lanesInput));
            edits.put("mc-control-lanes", text(controlLanesInput));
            edits.put("mc-connect-parallel", text(connectParallelInput));
            edits.put("mc-min-ready", text(minReadyInput));
            edits.put("mc-max-streams-per-lane", text(maxStreamsInput));
            edits.put("traffic-max-payload", text(trafficPayloadInput));
            edits.put("traffic-min-delay", text(trafficMinDelayInput));
            edits.put("traffic-max-delay", text(trafficMaxDelayInput));
            edits.put("liveness-interval", text(liveIntervalInput));
            edits.put("liveness-timeout", text(liveTimeoutInput));
            edits.put("liveness-failures", text(liveFailuresInput));
            String rewritten = rewriteParams(selected.link, edits);
            saveProfile(selected.id, selected.name, rewritten);
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_LINK, rewritten).apply();
            setStatus("Параметры профиля сохранены.");
            renderActiveTab();
        } catch (Exception e) {
            setStatus("Не смог сохранить параметры: " + e.getMessage());
        }
    }

    private void saveEditorProfile() {
        try {
            String rawLink = linkInput == null ? "" : linkInput.getText().toString().trim();
            OlcConfig config = OlcUriParser.parse(rawLink);
            String name = profileNameInput == null ? "" : profileNameInput.getText().toString().trim();
            if (name.isEmpty()) name = buildProfileName(config);
            String id = editingProfileId;
            if (id == null || id.trim().isEmpty()) {
                String existing = findProfileIdByLink(rawLink);
                id = existing == null ? String.valueOf(System.currentTimeMillis()) : existing;
                addProfileId(id);
            }
            saveProfile(id, name, rawLink);
            selectedProfileId = id;
            getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                    .putString(KEY_SELECTED_PROFILE_ID, id)
                    .putString(KEY_LINK, rawLink)
                    .apply();
            setStatus("Профиль сохранён: " + name);
            activeTab = TAB_PROFILES;
            renderActiveTab();
            openProfileEditor(getSelectedProfile(), false);
        } catch (Exception e) {
            setStatus(humanError("bad_link: " + e.getMessage()));
            setDetails("Parser error: " + safe(e.getMessage()));
        }
    }

    private void deleteEditingProfile() {
        if (editingProfileId == null || editingProfileId.trim().isEmpty()) return;
        SharedPreferences.Editor edit = getSharedPreferences(PREFS, MODE_PRIVATE).edit();
        edit.remove("profile_" + editingProfileId + "_link");
        edit.remove("profile_" + editingProfileId + "_name");
        edit.remove("profile_" + editingProfileId + "_carrier");
        edit.remove("profile_" + editingProfileId + "_transport");
        if (editingProfileId.equals(selectedProfileId)) {
            selectedProfileId = "";
            edit.remove(KEY_SELECTED_PROFILE_ID);
        }
        edit.apply();
        removeProfileId(editingProfileId);
        editingProfileId = null;
        setStatus("Профиль удалён.");
        renderActiveTab();
    }

    private void selectProfile(Profile profile) {
        if (profile == null) return;
        selectedProfileId = profile.id;
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putString(KEY_SELECTED_PROFILE_ID, profile.id)
                .putString(KEY_LINK, profile.link)
                .apply();
        setStatus("Выбран профиль: " + profile.name);
        refreshDynamicUi();
    }

    private void saveProfile(String id, String name, String link) throws Exception {
        OlcConfig config = OlcUriParser.parse(link);
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putString("profile_" + id + "_link", link)
                .putString("profile_" + id + "_name", name)
                .putString("profile_" + id + "_carrier", config.carrier)
                .putString("profile_" + id + "_transport", config.transport)
                .apply();
    }

    private List<Profile> loadProfiles() {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        List<Profile> out = new ArrayList<>();
        for (String id : getProfileIds()) {
            String link = prefs.getString("profile_" + id + "_link", "");
            if (link == null || link.trim().isEmpty()) continue;
            String name = prefs.getString("profile_" + id + "_name", "olcRTC profile");
            String carrier = prefs.getString("profile_" + id + "_carrier", "unknown");
            String transport = prefs.getString("profile_" + id + "_transport", "unknown");
            out.add(new Profile(id, name, link, carrier, transport));
        }
        return out;
    }

    private Profile getSelectedProfile() {
        if (selectedProfileId == null || selectedProfileId.trim().isEmpty()) return null;
        for (Profile profile : loadProfiles()) {
            if (profile.id.equals(selectedProfileId)) return profile;
        }
        return null;
    }

    private List<String> getProfileIds() {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        String raw = prefs.getString(KEY_PROFILE_IDS, "");
        List<String> ids = new ArrayList<>();
        if (raw == null || raw.trim().isEmpty()) return ids;
        for (String part : raw.split(",")) {
            String id = part.trim();
            if (!id.isEmpty() && !ids.contains(id)) ids.add(id);
        }
        return ids;
    }

    private void addProfileId(String id) {
        List<String> ids = getProfileIds();
        if (!ids.contains(id)) ids.add(id);
        saveProfileIds(ids);
    }

    private void removeProfileId(String id) {
        List<String> ids = getProfileIds();
        ids.remove(id);
        saveProfileIds(ids);
    }

    private void saveProfileIds(List<String> ids) {
        StringBuilder sb = new StringBuilder();
        for (String id : ids) {
            if (sb.length() > 0) sb.append(",");
            sb.append(id);
        }
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_PROFILE_IDS, sb.toString()).apply();
    }

    private String findProfileIdByLink(String link) {
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        for (String id : getProfileIds()) {
            if (link.equals(prefs.getString("profile_" + id + "_link", ""))) return id;
        }
        return null;
    }

    private String rewriteTransport(String raw, String transport) {
        OlcConfig config = OlcUriParser.parse(raw);
        String uri = extractOlcUri(raw);
        int q = uri.indexOf('?');
        int at = uri.indexOf('@', q + 1);
        if (q <= 0 || at <= q) throw new IllegalArgumentException("bad URI");
        return uri.substring(0, q + 1) + defaultTransportSpec(config, transport) + uri.substring(at);
    }

    private String rewriteParams(String raw, Map<String, String> edits) {
        OlcConfig config = OlcUriParser.parse(raw);
        String uri = extractOlcUri(raw);
        int q = uri.indexOf('?');
        int at = uri.indexOf('@', q + 1);
        if (q <= 0 || at <= q) throw new IllegalArgumentException("bad URI");

        Map<String, String> params = new LinkedHashMap<>(config.params);
        for (Map.Entry<String, String> entry : edits.entrySet()) {
            String value = entry.getValue();
            if (value == null || value.trim().isEmpty()) params.remove(entry.getKey());
            else params.put(entry.getKey(), value.trim());
        }
        return uri.substring(0, q + 1) + buildTransportSpec(config.transport, params) + uri.substring(at);
    }

    private String extractOlcUri(String raw) {
        String value = raw == null ? "" : raw.trim();
        int start = value.toLowerCase(Locale.ROOT).indexOf("olcrtc://");
        if (start >= 0) value = value.substring(start).trim();
        int cr = value.indexOf('\r');
        int lf = value.indexOf('\n');
        int end = -1;
        if (cr >= 0 && lf >= 0) end = Math.min(cr, lf);
        else if (cr >= 0) end = cr;
        else if (lf >= 0) end = lf;
        return end >= 0 ? value.substring(0, end).trim() : value;
    }

    private String defaultTransportSpec(OlcConfig base, String transport) {
        Map<String, String> params = new LinkedHashMap<>();
        if (OlcUriParser.TRANSPORT_VP8.equals(transport)) {
            params.put("vp8-fps", "25");
            params.put("vp8-batch", "4");
        } else if (OlcUriParser.TRANSPORT_SEI.equals(transport)) {
            params.put("fps", "30");
            params.put("batch", "8");
            params.put("frag", "700");
            params.put("sei-ack-ms", "10000");
            params.put("mc-lanes", "12");
            params.put("liveness-timeout", "60s");
            params.put("liveness-failures", "3");
        } else if (OlcUriParser.TRANSPORT_VIDEO.equals(transport)) {
            params.put("video-codec", "h264");
            params.put("video-width", "640");
            params.put("video-height", "360");
            params.put("video-fps", "15");
        } else if (!OlcUriParser.TRANSPORT_DATA.equals(transport)) {
            throw new IllegalArgumentException("unsupported transport: " + transport);
        }
        if (base != null && base.params.containsKey("link")) params.put("link", base.params.get("link"));
        if (base != null && base.params.containsKey("client-id")) params.put("client-id", base.params.get("client-id"));
        return buildTransportSpec(transport, params);
    }

    private String buildTransportSpec(String transport, Map<String, String> params) {
        if (params == null || params.isEmpty()) return transport;
        StringBuilder sb = new StringBuilder(transport).append("<");
        boolean first = true;
        for (Map.Entry<String, String> e : params.entrySet()) {
            if (e.getKey() == null || e.getKey().trim().isEmpty()) continue;
            if (!first) sb.append("&");
            sb.append(e.getKey().trim()).append("=").append(e.getValue() == null ? "" : e.getValue().trim());
            first = false;
        }
        sb.append(">");
        return sb.toString();
    }

    private void applyServiceStatus(String rawStatus) {
        addRecentEvent(rawStatus);
        setStatus(compactStatus(rawStatus));
        setDetails(shortDetails(rawStatus));
        updateStateFromStatus(rawStatus);
    }

    private void addRecentEvent(String event) {
        if (event == null || event.trim().isEmpty()) return;
        String compact = firstLine(event.trim());
        if (!recentEvents.isEmpty() && recentEvents.get(0).equals(compact)) return;
        recentEvents.add(0, compact);
        while (recentEvents.size() > 30) recentEvents.remove(recentEvents.size() - 1);
    }

    private void updateStateFromStatus(String status) {
        String s = status == null ? "" : status.toLowerCase(Locale.ROOT);
        if ("connected".equalsIgnoreCase(telemetryState) || s.contains("vpn connected")) {
            applyConnectionState(STATE_CONNECTED, "Подключено");
        } else if ("connecting".equalsIgnoreCase(telemetryState)
                || "reconnecting".equalsIgnoreCase(telemetryState)
                || s.contains("olcrtc подключён")
                || s.contains("подключаю olcrtc")
                || s.contains("автопереподключение")
                || s.contains("сеть изменилась")
                || s.contains("keepalive")) {
            applyConnectionState(STATE_CONNECTING, "Подключение");
        } else if (s.contains("ошибка") || s.contains("не выдано") || s.contains("отключаюсь") || s.contains("отключено") || s.contains("stopped")) {
            applyConnectionState(STATE_DISCONNECTED, "Отключено");
        }
    }

    private void applyConnectionState(int state, String subtitle) {
        connectionState = state;
        if (toggleButton != null) {
            if (state == STATE_CONNECTED) {
                toggleButton.setText("Отключить");
                toggleButton.setTextColor(Color.WHITE);
                toggleButton.setBackground(gradientButton());
            } else if (state == STATE_CONNECTING) {
                toggleButton.setText("Остановить");
                toggleButton.setTextColor(COLOR_TEXT_BRIGHT);
                toggleButton.setBackground(roundedDrawable("#1A1928", 16, "#2A2A3E", 1));
            } else {
                toggleButton.setText("Подключить");
                toggleButton.setTextColor(Color.WHITE);
                toggleButton.setBackground(gradientButton());
            }
        }
        if (statusBadge != null && subtitle != null) statusBadge.setText(subtitle);
    }

    private String statusBadgeText() {
        String name = !telemetryCarrier.isEmpty() ? telemetryCarrier : selectedProfileCarrier();
        if (connectionState == STATE_CONNECTED) return "Подключено · " + displayCarrier(name);
        if (connectionState == STATE_CONNECTING) return "Подключение · " + displayCarrier(name);
        return "Отключено · " + displayCarrier(name);
    }

    private String statusDotColor() {
        if (connectionState == STATE_CONNECTED) return "#00D2FF";
        if (connectionState == STATE_CONNECTING) return "#6C5CE7";
        return "#444452";
    }

    private String selectedProfileCarrier() {
        Profile selected = getSelectedProfile();
        return selected == null ? "XLTD" : selected.carrier;
    }

    private String activeTransportLabel() {
        String transport = !telemetryTransport.isEmpty() ? telemetryTransport : selectedProfileTransport();
        if (transport == null || transport.isEmpty()) return "transport: —";
        if (OlcUriParser.TRANSPORT_SEI.equals(transport)) return "SEI · " + telemetryLanes + " lanes";
        if (OlcUriParser.TRANSPORT_VP8.equals(transport)) return "VP8";
        if (OlcUriParser.TRANSPORT_VIDEO.equals(transport)) return "Video";
        if (OlcUriParser.TRANSPORT_DATA.equals(transport)) return "Data";
        return transport;
    }

    private String selectedProfileTransport() {
        Profile selected = getSelectedProfile();
        return selected == null ? "" : selected.transport;
    }

    private String profileTitle(Profile profile) {
        if (profile == null) return "XLTD · —";
        return displayCarrier(profile.carrier) + " · " + transportShort(profile.transport);
    }

    private String profileMeta(Profile profile) {
        if (profile == null) return "";
        try {
            OlcConfig config = OlcUriParser.parse(profile.link);
            if (OlcUriParser.TRANSPORT_SEI.equals(config.transport)) {
                return "seichannel · lanes=" + lanesFor(config) + " · fps=" + config.param("fps", config.param("sei-fps", "30"));
            }
            if (OlcUriParser.TRANSPORT_VP8.equals(config.transport)) {
                return "vp8channel · batch=" + config.param("vp8-batch", config.param("batch", "4")) + " · fps=" + config.param("vp8-fps", config.param("fps", "25"));
            }
            if (OlcUriParser.TRANSPORT_VIDEO.equals(config.transport)) {
                return "videochannel · fps=" + config.param("video-fps", config.param("fps", "15"));
            }
            return config.transport + " · " + displayCarrier(config.carrier);
        } catch (Exception ignored) {
            return profile.carrier + " · " + profile.transport + " · " + lanesLabel(profile.link);
        }
    }

    private String profileIcon(Profile profile) {
        String transport = profile == null ? "" : profile.transport;
        if (OlcUriParser.TRANSPORT_SEI.equals(transport)) return "↯";
        if (OlcUriParser.TRANSPORT_VP8.equals(transport)) return "♪";
        if (OlcUriParser.TRANSPORT_VIDEO.equals(transport)) return "▣";
        return "⌁";
    }

    private String transportShort(String transport) {
        if (OlcUriParser.TRANSPORT_SEI.equals(transport)) return "SEI";
        if (OlcUriParser.TRANSPORT_VP8.equals(transport)) return "VP8";
        if (OlcUriParser.TRANSPORT_VIDEO.equals(transport)) return "Video";
        if (OlcUriParser.TRANSPORT_DATA.equals(transport)) return "Data";
        return transport == null || transport.isEmpty() ? "—" : transport;
    }

    private int profileQualityLevel(Profile profile) {
        if (profile != null && profile.id.equals(selectedProfileId)) {
            if (connectionState == STATE_CONNECTED) {
                if (probeLatencyMs < 0) return 3;
                if (probeLatencyMs <= 80) return 4;
                if (probeLatencyMs <= 180) return 3;
                if (probeLatencyMs <= 350) return 2;
                return 1;
            }
            if (connectionState == STATE_CONNECTING) return 2;
            return 1;
        }
        if (profile != null && OlcUriParser.TRANSPORT_SEI.equals(profile.transport)) return 3;
        return 2;
    }

    private int transportAccent(String transport) {
        if (OlcUriParser.TRANSPORT_SEI.equals(transport)) return COLOR_SEI;
        if (OlcUriParser.TRANSPORT_VP8.equals(transport)) return COLOR_VP8;
        if (OlcUriParser.TRANSPORT_VIDEO.equals(transport)) return COLOR_VIDEO;
        if (OlcUriParser.TRANSPORT_DATA.equals(transport)) return COLOR_PRIMARY;
        return COLOR_TEXT_DIM;
    }

    private String colorHex(int color) {
        return String.format(Locale.US, "#%06X", 0xFFFFFF & color);
    }

    private String compactStatus(String raw) {
        String s = raw == null ? "" : raw.trim();
        String lower = s.toLowerCase(Locale.ROOT);
        if (lower.contains("vpn connected")) return "VPN подключён. Трафик идёт через туннель.";
        if (lower.contains("отключено")) return "VPN отключён.";
        if (lower.contains("ссылка разобрана")) return "Ссылка принята. Готовлю подключение.";
        if (lower.contains("dns auto")) return "DNS выбран автоматически.";
        if (lower.contains("подключаю olcrtc")) return "Подключаю olcRTC...";
        if (lower.contains("локальный socks")) return "olcRTC подключён. Проверяю локальный SOCKS.";
        if (lower.contains("remote connect ok")) return "Серверная сторона отвечает на CONNECT.";
        if (lower.contains("автопереподключение")) return firstLine(s);
        if (lower.contains("сеть изменилась")) return "Сеть изменилась. Пересоздаю туннель.";
        if (lower.contains("keepalive fail")) return "Туннель отвечает нестабильно.";
        if (lower.contains("ошибка") || lower.contains("failed") || lower.contains("exception")) return humanError(s);
        return firstLine(s);
    }

    private String shortDetails(String raw) {
        if (raw == null || raw.trim().isEmpty()) return "Нет деталей.";
        String s = raw.trim();
        s = s.replaceAll("(?i)(key=)[0-9a-f]{16,}", "$1hidden");
        s = s.replaceAll("(?i)(#)[0-9a-f]{16,}", "$1hidden");
        return s.length() > 900 ? s.substring(0, 900) + "\n..." : s;
    }

    private String humanError(String raw) {
        String s = raw == null ? "" : raw.toLowerCase(Locale.ROOT);
        if (s.contains("videochannel") && s.contains("ffmpeg")) return "videochannel требует Android ffmpeg core. Пересобери APK через scripts/build_combo_aar.sh.";
        if ((s.contains("seichannel") || s.contains("videochannel")) && (s.contains("setseioptions") || s.contains("setvideooptions") || s.contains("startwithtransport") || s.contains("combo aar"))) return "Нужен свежий combo AAR с поддержкой universal-carrier.";
        if (s.contains("bad_link") || s.contains("empty olcrtc link")) return "Вставь корректную olcRTC-ссылку.";
        if (s.contains("combined mobile aar") || s.contains("combo aar")) return "Core не найден. Собери combo AAR и пересобери APK.";
        if (s.contains("vpn permission") || s.contains("tun establish") || s.contains("permission not granted")) return "Android не разрешил создать VPN-подключение.";
        if (s.contains("ice failed") || s.contains("olcrtc core stopped")) return "Канал olcRTC оборвался. Приложение попробует переподключиться.";
        if (s.contains("keepalive failed") || s.contains("keepalive fail")) return "Туннель перестал отвечать. Переподключаюсь.";
        if (s.contains("remote not ready") || s.contains("host unreachable") || s.contains("timeout")) return "Удалённая сторона не ответила. Попробую переподключиться.";
        if (s.contains("connection refused")) return "Соединение отклонено. Проверь ссылку и сервер.";
        return "Ошибка подключения. Детали ниже.";
    }

    private String tagForEvent(String event) {
        String s = event == null ? "" : event.toLowerCase(Locale.ROOT);
        if (s.contains("vpn connected") || s.contains("connect ok") || s.contains("подключён")) return "OK";
        if (s.contains("dns")) return "DNS";
        if (s.contains("tun") || s.contains("vpn")) return "TUN";
        if (s.contains("ошибка") || s.contains("fail") || s.contains("timeout")) return "WARN";
        return "LOG";
    }

    private int tagColor(String tag) {
        if ("OK".equals(tag)) return COLOR_SEI;
        if ("WARN".equals(tag)) return COLOR_VP8;
        if ("DNS".equals(tag)) return COLOR_PRIMARY;
        return COLOR_TEXT_DIM;
    }

    private String compactEvent(String event) {
        String s = firstLine(event);
        return s.length() > 110 ? s.substring(0, 110) + "..." : s;
    }

    private String buildProfileName(OlcConfig config) {
        if (config.comment != null && !config.comment.trim().isEmpty() && !"direct".equalsIgnoreCase(config.comment.trim())) return config.comment.trim();
        if (config.clientId != null && !config.clientId.trim().isEmpty() && !"default".equalsIgnoreCase(config.clientId.trim())) return config.carrier + " | " + config.transport + " | " + config.clientId;
        return config.carrier + " | " + config.transport;
    }

    private String lanesLabel(String link) {
        try {
            OlcConfig config = OlcUriParser.parse(link);
            int lanes = lanesFor(config);
            return lanes > 1 ? lanes + " lanes" : "single lane";
        } catch (Exception ignored) {
            return "unknown";
        }
    }

    private int lanesFor(OlcConfig config) {
        if (config == null || !OlcUriParser.TRANSPORT_SEI.equals(config.transport)) return 1;
        return Math.max(1, config.intParam("mc-lanes", config.intParam("sei-lanes", config.intParam("lanes", 1))));
    }

    private void setStatus(String text) {
        if (statusView != null) statusView.setText(text);
        if (text != null && !text.trim().isEmpty()) {
            addRecentEvent(text);
            refreshEvents();
        }
    }

    private void setDetails(String text) {
        if (detailsView != null) detailsView.setText(text == null ? "" : text);
    }

    private void hideEditorFocus() {
        if (linkInput != null) linkInput.clearFocus();
        if (profileNameInput != null) profileNameInput.clearFocus();
        try {
            InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
            View view = getCurrentFocus();
            if (imm != null && view != null) imm.hideSoftInputFromWindow(view.getWindowToken(), 0);
        } catch (Throwable ignored) {
        }
    }

    private boolean isIgnoringBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true;
        try {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            return pm != null && pm.isIgnoringBatteryOptimizations(getPackageName());
        } catch (Throwable ignored) {
            return false;
        }
    }

    private void requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            setStatus("На этой версии Android отдельное разрешение фона не нужно.");
            return;
        }
        if (isIgnoringBatteryOptimizations()) {
            setStatus("Фоновая работа уже разрешена.");
            return;
        }
        try {
            Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + getPackageName()));
            startActivity(intent);
            setStatus("Подтверди отключение энергосбережения для стабильного VPN.");
        } catch (Throwable t) {
            try {
                startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));
            } catch (Throwable ignored) {
                setStatus("Не удалось открыть настройки батареи.");
            }
        }
    }

    private TextView sectionTitle(String text) {
        TextView view = smallMono(text);
        view.setTextColor(COLOR_TEXT_MUTED);
        view.setTypeface(Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView smallMono(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 10);
        view.setTypeface(Typeface.MONOSPACE);
        return view;
    }

    private TextView bodyText(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(COLOR_TEXT_TERTIARY);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        view.setLineSpacing(0f, 1.15f);
        return view;
    }

    private TextView smallText(String text) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(COLOR_TEXT_DIM);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
        view.setLineSpacing(0f, 1.15f);
        return view;
    }

    private TextView smallAction(String text) {
        TextView view = smallMono(text);
        view.setTextColor(COLOR_PRIMARY);
        view.setPadding(dp(8), dp(5), dp(8), dp(5));
        view.setClickable(true);
        return view;
    }

    private TextView primarySmallButton(String text) {
        TextView b = new TextView(this);
        b.setText(text);
        b.setGravity(Gravity.CENTER);
        b.setTextColor(Color.WHITE);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setPadding(dp(14), dp(12), dp(14), dp(12));
        b.setBackground(gradientButton());
        b.setClickable(true);
        return b;
    }

    private TextView secondarySmallButton(String text) {
        TextView b = primarySmallButton(text);
        b.setTextColor(COLOR_PRIMARY_PALE);
        b.setBackground(roundedDrawable("#1A1928", 14, "#2A2A3E", 1));
        return b;
    }

    private LinearLayout card() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(dp(14), dp(14), dp(14), dp(14));
        layout.setBackground(roundedDrawable("#1A1928", 16, "#2A2A3E", 1));
        return layout;
    }

    private LinearLayout row() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        return row;
    }

    private GradientDrawable roundedDrawable(String fillColor, int radiusDp, String strokeColor, int strokeDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(Color.parseColor(fillColor));
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeColor != null && strokeDp > 0) drawable.setStroke(dp(strokeDp), Color.parseColor(strokeColor));
        return drawable;
    }

    private GradientDrawable gradientButton() {
        GradientDrawable drawable = new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, new int[]{
                COLOR_PRIMARY,
                COLOR_SEI
        });
        drawable.setCornerRadius(dp(16));
        return drawable;
    }

    private LinearLayout.LayoutParams navLp() {
        return new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
    }

    private LinearLayout.LayoutParams lpMatchWrap() {
        LinearLayout.LayoutParams lp = lpMatchWrapNoMargin();
        lp.setMargins(0, dp(6), 0, dp(6));
        return lp;
    }

    private LinearLayout.LayoutParams lpMatchWrapNoMargin() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private LinearLayout.LayoutParams lpWrapWrapNoMargin() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private LinearLayout.LayoutParams fixedWidth(int width) {
        return new LinearLayout.LayoutParams(width, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String text(EditText edit) {
        return edit == null ? "" : edit.getText().toString().trim();
    }

    private String safe(String s) {
        return s == null ? "" : s;
    }

    private String firstLine(String s) {
        if (s == null || s.trim().isEmpty()) return "";
        String line = s.trim().split("\\r?\\n", 2)[0].trim();
        return line.length() > 140 ? line.substring(0, 140) + "..." : line;
    }

    private String displayCarrier(String carrier) {
        if (carrier == null || carrier.trim().isEmpty()) return "XLTD";
        if ("mtslink".equalsIgnoreCase(carrier)) return "MTS Link";
        return carrier;
    }

    private String currentShortTime() {
        java.text.SimpleDateFormat fmt = new java.text.SimpleDateFormat("HH:mm", Locale.US);
        return fmt.format(new java.util.Date());
    }

    private String formatUptime(long ms) {
        long sec = Math.max(0L, ms / 1000L);
        long h = sec / 3600L;
        long m = (sec % 3600L) / 60L;
        long s = sec % 60L;
        if (h > 0) return String.format(Locale.US, "%d:%02d", h, m);
        return String.format(Locale.US, "%d:%02d", m, s);
    }

    private String formatRate(long bps) {
        double value = Math.max(0L, bps);
        if (value >= 1024 * 1024) return String.format(Locale.US, "%.1f MB/s", value / 1024d / 1024d);
        if (value >= 1024) return String.format(Locale.US, "%.0f KB/s", value / 1024d);
        return Math.round(value) + " B/s";
    }

    private String formatBytes(long bytes) {
        ByteLabel label = splitBytes(bytes);
        return label.value + " " + label.unit;
    }

    private ByteLabel splitBytes(long bytes) {
        double value = Math.max(0L, bytes);
        if (value >= 1024d * 1024d * 1024d) return new ByteLabel(String.format(Locale.US, "%.1f", value / 1024d / 1024d / 1024d), "GB");
        if (value >= 1024d * 1024d) return new ByteLabel(String.format(Locale.US, "%.1f", value / 1024d / 1024d), "MB");
        if (value >= 1024d) return new ByteLabel(String.format(Locale.US, "%.0f", value / 1024d), "KB");
        return new ByteLabel(String.valueOf(Math.round(value)), "B");
    }

    private static final class SignalBarsView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private int level = 0;
        private boolean active = false;

        SignalBarsView(Context context) {
            super(context);
        }

        void setLevel(int level) {
            this.level = Math.max(0, Math.min(4, level));
            invalidate();
        }

        void setActive(boolean active) {
            this.active = active;
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float density = getResources().getDisplayMetrics().density;
            float gap = 2f * density;
            float barWidth = 3f * density;
            float radius = 2f * density;
            float maxHeight = getHeight() - 4f * density;
            float left = Math.max(0f, getWidth() - (barWidth * 4f + gap * 3f));
            float bottom = getHeight() - 2f * density;
            for (int i = 0; i < 4; i++) {
                float height = Math.max(4f * density, maxHeight * (0.3f + i * 0.23f));
                paint.setColor(i < level ? (active ? COLOR_PRIMARY : COLOR_PRIMARY_DEEP) : COLOR_SURFACE_LINE);
                float x = left + i * (barWidth + gap);
                canvas.drawRoundRect(x, bottom - height, x + barWidth, bottom, radius, radius, paint);
            }
        }
    }

    private static final class ByteLabel {
        final String value;
        final String unit;

        ByteLabel(String value, String unit) {
            this.value = value;
            this.unit = unit;
        }
    }

    // ── Hero helpers (design v2) ──────────────────────────────────────────────

    /**
     * Format download speed for the hero display with 2 decimal places for MB/s,
     * whole number for KB/s, and bare bytes for very slow connections.
     */
    private ByteLabel formatSpeedHero(long bps) {
        double v = Math.max(0, bps);
        if (v >= 1024d * 1024d) return new ByteLabel(String.format(Locale.US, "%.2f", v / 1024d / 1024d), "MB/s");
        if (v >= 1024d)         return new ByteLabel(String.format(Locale.US, "%.0f", v / 1024d), "KB/s");
        return new ByteLabel(String.valueOf(Math.round(v)), "B/s");
    }

    /**
     * Single-line context string shown under the speed hero when connected:
     * "MTS Link · SEI · 12 lanes · 74 ms"
     * Falls back to short state labels while disconnected/connecting.
     */
    private String heroContextLine() {
        if (connectionState == STATE_DISCONNECTED) return "отключено";
        if (connectionState == STATE_CONNECTING)   return "подключение...";
        StringBuilder sb = new StringBuilder();
        if (!telemetryCarrier.isEmpty())
            sb.append(displayCarrier(telemetryCarrier)).append(" · ");
        if (!telemetryTransport.isEmpty())
            sb.append(telemetryTransport.toLowerCase(Locale.ROOT)).append(" · ");
        if (telemetryLanes > 1)
            sb.append(telemetryLanes).append(" lanes · ");
        if (probeLatencyMs >= 0)
            sb.append(probeLatencyMs).append(" ms");
        String result = sb.toString();
        while (result.endsWith(" · ")) result = result.substring(0, result.length() - 3);
        return result.isEmpty() ? "подключено" : result;
    }

    /**
     * Small pill text showing total session traffic and uptime.
     * "Сессия 12.4 MB · 0:42"
     */
    private String sessionPillText() {
        if (connectionState != STATE_CONNECTED) return "нет сессии";
        long total = sessionRxBytes + sessionTxBytes;
        return "Сессия " + formatBytes(total) + " · " + formatUptime(uptimeMs);
    }

    // ── SVG-style bottom nav icon (design v2) ────────────────────────────────

    /**
     * Canvas-drawn line icon with 1.5 dp stroke width and rounded caps/joins,
     * matching the style spec from the design HTML (same family as rabbit mascot).
     */
    private static final class NavIconView extends android.view.View {
        static final int ICON_HOME     = 0;
        static final int ICON_PROFILES = 1;
        static final int ICON_TRAFFIC  = 2;
        static final int ICON_SETTINGS = 3;

        private final android.graphics.Paint paint = new android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG);
        private int iconType = ICON_HOME;
        private int color    = 0xFF444456;

        NavIconView(android.content.Context ctx) {
            super(ctx);
            paint.setStyle(android.graphics.Paint.Style.STROKE);
            paint.setStrokeCap(android.graphics.Paint.Cap.ROUND);
            paint.setStrokeJoin(android.graphics.Paint.Join.ROUND);
        }

        void setIconType(int type)  { iconType = type; invalidate(); }
        void setColor(int c)        { color    = c;    invalidate(); }

        @Override
        protected void onDraw(android.graphics.Canvas canvas) {
            super.onDraw(canvas);
            float d  = getResources().getDisplayMetrics().density;
            paint.setStrokeWidth(1.5f * d);
            paint.setColor(color);
            float w = getWidth(), h = getHeight();
            float cx = w * 0.5f, cy = h * 0.5f;
            float s  = Math.min(w, h) * 0.78f;
            float l = cx - s * 0.5f, r = cx + s * 0.5f;
            float t = cy - s * 0.5f, b = cy + s * 0.5f;

            switch (iconType) {
                case ICON_HOME:     drawHome(canvas, l, t, r, b, d); break;
                case ICON_PROFILES: drawProfiles(canvas, l, t, r, b); break;
                case ICON_TRAFFIC:  drawTraffic(canvas, l, t, r, b, d); break;
                case ICON_SETTINGS: drawSettings(canvas, l, t, r, b, d); break;
            }
        }

        private void drawHome(android.graphics.Canvas cv, float l, float t, float r, float b, float d) {
            float cx = (l + r) * 0.5f;
            float roofBase = t + (b - t) * 0.46f;
            float bodyL = l + (r - l) * 0.13f;
            float bodyR = r - (r - l) * 0.13f;
            // Roof triangle
            android.graphics.Path p = new android.graphics.Path();
            p.moveTo(l, roofBase); p.lineTo(cx, t); p.lineTo(r, roofBase);
            cv.drawPath(p, paint);
            // Body left + bottom + right (open top)
            android.graphics.Path body = new android.graphics.Path();
            body.moveTo(bodyL, roofBase); body.lineTo(bodyL, b);
            body.lineTo(bodyR, b);       body.lineTo(bodyR, roofBase);
            cv.drawPath(body, paint);
            // Door slot
            float dw = (r - l) * 0.16f;
            float doorT = b - (b - roofBase) * 0.48f;
            android.graphics.Path door = new android.graphics.Path();
            door.moveTo(cx - dw, b); door.lineTo(cx - dw, doorT);
            door.lineTo(cx + dw, doorT); door.lineTo(cx + dw, b);
            cv.drawPath(door, paint);
        }

        private void drawProfiles(android.graphics.Canvas cv, float l, float t, float r, float b) {
            float mid = (t + b) * 0.5f;
            float gap = (b - t) * 0.27f;
            // Three lines, each slightly shorter than the previous (left-to-right trim)
            cv.drawLine(l, mid - gap, r, mid - gap, paint);
            cv.drawLine(l, mid,       r - (r - l) * 0.22f, mid, paint);
            cv.drawLine(l, mid + gap, r - (r - l) * 0.44f, mid + gap, paint);
        }

        private void drawTraffic(android.graphics.Canvas cv, float l, float t, float r, float b, float d) {
            float cxL = l + (r - l) * 0.30f;
            float cxR = l + (r - l) * 0.70f;
            float ah  = (b - t) * 0.55f;
            float hw  = (r - l) * 0.14f;   // arrowhead half-width
            float hh  = ah * 0.36f;         // arrowhead height
            float top = (t + b) * 0.5f - ah * 0.5f;
            float bot = (t + b) * 0.5f + ah * 0.5f;
            // Up arrow
            cv.drawLine(cxL, bot, cxL, top, paint);
            cv.drawLine(cxL, top, cxL - hw, top + hh, paint);
            cv.drawLine(cxL, top, cxL + hw, top + hh, paint);
            // Down arrow
            cv.drawLine(cxR, top, cxR, bot, paint);
            cv.drawLine(cxR, bot, cxR - hw, bot - hh, paint);
            cv.drawLine(cxR, bot, cxR + hw, bot - hh, paint);
        }

        private void drawSettings(android.graphics.Canvas cv, float l, float t, float r, float b, float d) {
            float mid = (t + b) * 0.5f;
            float gap = (b - t) * 0.26f;
            float kr  = (b - t) * 0.13f; // knob radius
            // Top track with knob at 65%
            float k1x = l + (r - l) * 0.65f;
            cv.drawLine(l, mid - gap, k1x - kr, mid - gap, paint);
            cv.drawLine(k1x + kr, mid - gap, r, mid - gap, paint);
            // Knob: temporarily fill for solid dot
            paint.setStyle(android.graphics.Paint.Style.FILL);
            cv.drawCircle(k1x, mid - gap, kr, paint);
            paint.setStyle(android.graphics.Paint.Style.STROKE);
            // Bottom track with knob at 32%
            float k2x = l + (r - l) * 0.32f;
            cv.drawLine(l, mid + gap, k2x - kr, mid + gap, paint);
            cv.drawLine(k2x + kr, mid + gap, r, mid + gap, paint);
            paint.setStyle(android.graphics.Paint.Style.FILL);
            cv.drawCircle(k2x, mid + gap, kr, paint);
            paint.setStyle(android.graphics.Paint.Style.STROKE);
        }
    }
}
