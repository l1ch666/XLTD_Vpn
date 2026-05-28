package com.s1dechain.olcrtcvpn;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Single Flutter activity that bridges Dart UI to the existing
 * {@link OlcVpnService} via MethodChannel (control) and two EventChannels
 * (telemetry / log).
 *
 * Channels match the names declared in
 * lib/services/android_vpn_bridge.dart.
 */
public class MainActivity extends FlutterActivity {

    private static final String CONTROL_CHANNEL   = "com.s1dechain.olcrtcvpn/control";
    private static final String TELEMETRY_CHANNEL = "com.s1dechain.olcrtcvpn/telemetry";
    private static final String LOG_CHANNEL       = "com.s1dechain.olcrtcvpn/log";

    private static final int REQ_VPN_PERMISSION = 1001;

    private MethodChannel control;
    private EventChannel.EventSink telemetrySink;
    private EventChannel.EventSink logSink;
    private BroadcastReceiver statusReceiver;
    private final Handler main = new Handler(Looper.getMainLooper());

    private String pendingStartLink; // captured before VpnService permission

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);

        control = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CONTROL_CHANNEL);
        control.setMethodCallHandler(this::onControl);

        new EventChannel(engine.getDartExecutor().getBinaryMessenger(), TELEMETRY_CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override public void onListen(Object args, EventChannel.EventSink sink) {
                        telemetrySink = sink;
                        // Push the cached snapshot so the UI doesn't show stale "disconnected"
                        Map<String, Object> snap = currentSnapshotMap();
                        if (snap != null) sink.success(snap);
                    }
                    @Override public void onCancel(Object args) {
                        telemetrySink = null;
                    }
                });

        new EventChannel(engine.getDartExecutor().getBinaryMessenger(), LOG_CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override public void onListen(Object args, EventChannel.EventSink sink) {
                        logSink = sink;
                    }
                    @Override public void onCancel(Object args) {
                        logSink = null;
                    }
                });

        registerStatusReceiver();
    }

    @Override
    protected void onDestroy() {
        if (statusReceiver != null) {
            try { unregisterReceiver(statusReceiver); } catch (Throwable ignored) {}
            statusReceiver = null;
        }
        super.onDestroy();
    }

    // ── MethodChannel dispatch ──────────────────────────────────────────

    private void onControl(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "healthCheck":
                result.success(true);
                break;

            case "start": {
                String uri = call.argument("uri");
                if (uri == null || uri.trim().isEmpty()) {
                    result.error("missing_uri", "uri is required", null);
                    return;
                }
                Intent prep = VpnService.prepare(this);
                if (prep != null) {
                    pendingStartLink = uri;
                    startActivityForResult(prep, REQ_VPN_PERMISSION);
                    result.success(false); // permission pending; UI will see CONNECTING later
                    return;
                }
                startService(uri);
                result.success(true);
                break;
            }

            case "stop": {
                Intent i = new Intent(this, OlcVpnService.class);
                i.setAction(OlcVpnService.ACTION_STOP);
                startService(i);
                result.success(true);
                break;
            }

            default:
                result.notImplemented();
        }
    }

    private void startService(String uri) {
        Intent i = new Intent(this, OlcVpnService.class);
        i.setAction(OlcVpnService.ACTION_START);
        i.putExtra(OlcVpnService.EXTRA_LINK, uri);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(i);
        } else {
            startService(i);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_VPN_PERMISSION) {
            if (resultCode == RESULT_OK && pendingStartLink != null) {
                startService(pendingStartLink);
            }
            pendingStartLink = null;
        }
    }

    // ── Telemetry / log bridge ──────────────────────────────────────────

    private void registerStatusReceiver() {
        IntentFilter filter = new IntentFilter(OlcVpnService.ACTION_STATUS);
        statusReceiver = new BroadcastReceiver() {
            @Override public void onReceive(Context context, Intent intent) {
                Map<String, Object> snap = decodeStatus(intent);
                if (telemetrySink != null && snap != null) {
                    main.post(() -> {
                        if (telemetrySink != null) telemetrySink.success(snap);
                    });
                }
                if (logSink != null) {
                    String event = intent.getStringExtra(OlcVpnService.EXTRA_EVENT);
                    if (event != null && !event.isEmpty()) {
                        Map<String, Object> line = new HashMap<>();
                        line.put("ts", System.currentTimeMillis());
                        line.put("tag", logTagFor(event));
                        line.put("msg", event);
                        main.post(() -> { if (logSink != null) logSink.success(line); });
                    }
                }
            }
        };
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(statusReceiver, filter);
        }
    }

    @Nullable
    private Map<String, Object> decodeStatus(Intent intent) {
        if (intent == null) return null;
        Map<String, Object> out = new HashMap<>();
        out.put("state", or(intent.getStringExtra(OlcVpnService.EXTRA_STATE), "disconnected"));
        out.put("carrier", or(intent.getStringExtra(OlcVpnService.EXTRA_CARRIER), ""));
        out.put("transport", or(intent.getStringExtra(OlcVpnService.EXTRA_TRANSPORT), ""));
        out.put("rxBps",        intent.getLongExtra(OlcVpnService.EXTRA_RX_BPS, 0L));
        out.put("txBps",        intent.getLongExtra(OlcVpnService.EXTRA_TX_BPS, 0L));
        out.put("sessionRx",    intent.getLongExtra(OlcVpnService.EXTRA_SESSION_RX_BYTES, 0L));
        out.put("sessionTx",    intent.getLongExtra(OlcVpnService.EXTRA_SESSION_TX_BYTES, 0L));
        out.put("latencyMs",    intent.getLongExtra(OlcVpnService.EXTRA_PROBE_LATENCY_MS, -1L));
        out.put("uptimeMs",     intent.getLongExtra(OlcVpnService.EXTRA_UPTIME_MS, 0L));
        return out;
    }

    @Nullable
    private Map<String, Object> currentSnapshotMap() {
        // Read the cached snapshot string ("...") if useful; we always start "disconnected"
        Map<String, Object> out = new HashMap<>();
        out.put("state", "disconnected");
        out.put("rxBps", 0);
        out.put("txBps", 0);
        out.put("sessionRx", 0);
        out.put("sessionTx", 0);
        out.put("latencyMs", -1);
        out.put("uptimeMs", 0);
        return out;
    }

    private String logTagFor(String event) {
        String e = event == null ? "" : event.toLowerCase();
        if (e.contains("ok") || e.contains("connect") || e.contains("active")) return "OK";
        if (e.contains("dns")) return "DNS";
        if (e.contains("tun") || e.contains("wintun")) return "TUN";
        if (e.contains("error") || e.contains("fail")) return "ERR";
        if (e.contains("hint") || e.contains("warn")) return "HINT";
        return "LOG";
    }

    @NonNull
    private static String or(@Nullable String v, @NonNull String def) {
        return v == null ? def : v;
    }

    // ── Deep-link (olcrtc://) → forward to Flutter ──────────────────────

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        forwardDeeplink(intent);
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        forwardDeeplink(getIntent());
    }

    private void forwardDeeplink(@Nullable Intent intent) {
        if (intent == null || intent.getData() == null) return;
        if (!"olcrtc".equalsIgnoreCase(intent.getData().getScheme())) return;
        if (control == null) return;
        main.postDelayed(() -> {
            if (control != null) control.invokeMethod("deeplink", intent.getDataString());
        }, 400);
    }
}
