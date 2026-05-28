package com.s1dechain.olcrtcvpn;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.IpPrefix;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.TrafficStats;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;

public final class OlcVpnService extends VpnService {
    public static final String ACTION_START = "com.s1dechain.olcrtcvpn.START";
    public static final String ACTION_STOP = "com.s1dechain.olcrtcvpn.STOP";
    public static final String ACTION_STATUS = "com.s1dechain.olcrtcvpn.STATUS";
    public static final String EXTRA_LINK = "link";
    public static final String EXTRA_STATUS = "status";
    public static final String EXTRA_STATE = "state";
    public static final String EXTRA_CARRIER = "carrier";
    public static final String EXTRA_TRANSPORT = "transport";
    public static final String EXTRA_LANES = "lanes";
    public static final String EXTRA_UPTIME_MS = "uptime_ms";
    public static final String EXTRA_SESSION_RX_BYTES = "session_rx_bytes";
    public static final String EXTRA_SESSION_TX_BYTES = "session_tx_bytes";
    public static final String EXTRA_RX_BPS = "rx_bps";
    public static final String EXTRA_TX_BPS = "tx_bps";
    public static final String EXTRA_PROBE_LATENCY_MS = "probe_latency_ms";
    public static final String EXTRA_EVENT = "event";

    private static final String TAG = "OlcVpnService";
    private static final String CHANNEL_ID = "olcrtc_vpn";
    private static final int NOTIFICATION_ID = 1001;
    private static final int SOCKS_PORT = 10808;
    private static final int DATA_MTU = 1500;
    // VP8 video transport is more fragile than DataChannel under Android VPN bursts.
    // Keep it below common carrier/video fragmentation pain points.
    private static final int VP8_MTU = 1040;
    private static final int DATA_TCP_DIAL_LIMIT = 8;
    private static final int VP8_TCP_DIAL_LIMIT = 2;
    private static final int STARTUP_TIMEOUT_MS = 22000;
    private static final int VP8_STARTUP_TIMEOUT_MS = 30000;
    // SEI multipath with mtslink can take 40-60 s for mc-min-ready lanes to bootstrap.
    // Give the Go runtime enough runway so Java doesn't race and kill the attempt.
    private static final int SEI_STARTUP_TIMEOUT_MS = 65000;
    private static final long VP8_STABILIZE_MS = 3500L;
    private static final int LOCAL_SOCKS_PROBE_ATTEMPTS = 8;
    private static final int LOCAL_SOCKS_PROBE_TIMEOUT_MS = 2500;
    private static final long KEEPALIVE_INTERVAL_MS = 30000L;
    private static final int KEEPALIVE_MAX_FAILURES = 3;
    private static final long NETWORK_RECONNECT_DELAY_MS = 4000L;
    private static final long NETWORK_RECONNECT_DEBOUNCE_MS = 15000L;
    private static final long NETWORK_CALLBACK_IGNORE_MS = 8000L;
    private static final long CORE_RECONNECT_DELAY_MS = 6000L;
    private static final long OLC_STORM_WINDOW_MS = 20000L;
    private static final int OLC_STORM_RECONNECT_THRESHOLD = 18;
    private static final int OLC_STORM_REMOTE_READY_THRESHOLD = 8;
    private static final int VP8_REMOTE_PROBE_ATTEMPTS = 16;
    private static final int DATA_REMOTE_PROBE_ATTEMPTS = 4;
    private static final int REMOTE_PROBE_TIMEOUT_MS = 4500;

    private static final String[] PUBLIC_VPN_DNS = new String[]{"1.1.1.1", "8.8.8.8", "77.88.8.8"};
    private static final String[] EXTRA_DNS_ROUTE_EXCLUDES = new String[]{"1.0.0.1", "8.8.4.4", "77.88.8.1"};
    private static final String TUNNEL_DNS_CLOUDFLARE = "1.1.1.1:53";
    private static final String TUNNEL_DNS_GOOGLE = "8.8.8.8:53";
    private static final String TUNNEL_DNS_YANDEX = "77.88.8.8:53";
    private static final String[] REMOTE_CONNECT_PROBE_TARGETS = new String[]{
            "1.1.1.1:443",
            "8.8.8.8:443",
            "77.88.8.8:443",
            "91.108.56.162:443"
    };
    private static volatile String lastStatusSnapshot = "";

    private final Object lock = new Object();
    private Thread worker;
    private ParcelFileDescriptor tunFd;
    private int detachedTunFd = -1;
    private Tun2SocksMobileBridge tun2socks;
    private OlcMobileBridge olc;
    private ConnectivityManager connectivityManager;
    private ConnectivityManager.NetworkCallback networkCallback;

    private volatile boolean stopRequested = false;
    private volatile boolean restartRequested = false;
    private volatile boolean controlledReconnectPending = false;
    private volatile String currentLink;
    private volatile int reconnectAttempt = 0;
    private volatile int workerGeneration = 0;
    private volatile int keepAliveFailures = 0;
    private volatile boolean tunEstablished = false;
    private volatile long ignoreNetworkEventsUntilMs = 0L;
    private volatile long lastNetworkReconnectAtMs = 0L;
    private volatile long lastOlcStormWindowStartMs = 0L;
    private volatile long lastCoreReconnectAtMs = 0L;
    private volatile int olcStormEvents = 0;
    private volatile int olcRemoteReadyEvents = 0;
    private volatile String activeNetworkSignature = "";
    private volatile OlcConfig activeConfig;
    private volatile long sessionStartedAtMs = 0L;
    private volatile long trafficBaseRx = -1L;
    private volatile long trafficBaseTx = -1L;
    private volatile long trafficLastRx = -1L;
    private volatile long trafficLastTx = -1L;
    private volatile long trafficLastAtMs = 0L;
    private volatile long sessionRxBytes = 0L;
    private volatile long sessionTxBytes = 0L;
    private volatile long rxBps = 0L;
    private volatile long txBps = 0L;
    private volatile long lastProbeLatencyMs = -1L;

    // ── Live telemetry ticker ──────────────────────────────────────────
    // Fires sendStatus() every TELEMETRY_TICK_MS while tunEstablished so the
    // UI gets live speed / uptime updates instead of waiting for the next
    // VPN state transition.
    private static final long TELEMETRY_TICK_MS = 1500L;
    private HandlerThread telemetryThread;
    private Handler telemetryHandler;
    private final Runnable telemetryTick = new Runnable() {
        @Override public void run() {
            if (tunEstablished) {
                try { sendStatus("tick"); } catch (Throwable ignored) {}
                if (telemetryHandler != null) {
                    telemetryHandler.postDelayed(this, TELEMETRY_TICK_MS);
                }
            }
        }
    };

    private void startTelemetryTicker() {
        stopTelemetryTicker();
        telemetryThread = new HandlerThread("xltd-telemetry");
        telemetryThread.start();
        telemetryHandler = new Handler(telemetryThread.getLooper());
        // Reset traffic baseline so the first measured byte is post-tunnel.
        trafficBaseRx = -1L;
        trafficBaseTx = -1L;
        trafficLastRx = -1L;
        trafficLastTx = -1L;
        trafficLastAtMs = 0L;
        sessionRxBytes = 0L;
        sessionTxBytes = 0L;
        rxBps = 0L;
        txBps = 0L;
        // First tick immediately so UI doesn't sit on stale "disconnected" values.
        telemetryHandler.post(telemetryTick);
    }

    private void stopTelemetryTicker() {
        if (telemetryHandler != null) telemetryHandler.removeCallbacksAndMessages(null);
        if (telemetryThread != null) {
            try { telemetryThread.quitSafely(); } catch (Throwable ignored) {}
        }
        telemetryThread = null;
        telemetryHandler = null;
    }

    public static String getLastStatusSnapshot() {
        return lastStatusSnapshot;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;

        String action = intent.getAction();
        if (ACTION_STOP.equals(action)) {
            stopRequested = true;
            restartRequested = false;
            controlledReconnectPending = false;
            currentLink = null;
            sendStatus("Отключаюсь...");
            shutdownResources();
            synchronized (lock) {
                resetSessionTelemetryLocked();
            }
            sendStatus("Отключено.");
            stopSelf();
            return START_NOT_STICKY;
        }

        if (ACTION_START.equals(action)) {
            String link = intent.getStringExtra(EXTRA_LINK);
            currentLink = link;
            stopRequested = false;
            reconnectAttempt = 0;
            startForegroundCompat("Starting...");
            startWorker(link);
            return START_STICKY;
        }

        return START_NOT_STICKY;
    }

    private void startWorker(String link) {
        synchronized (lock) {
            startWorkerLocked(link);
        }
    }

    private void startWorkerLocked(String link) {
        restartRequested = false;
        keepAliveFailures = 0;
        int generation = ++workerGeneration;
        resetSessionTelemetryLocked();
        shutdownResourcesLocked();
        worker = new Thread(() -> runVpnOnce(link, generation), "olcrtc-vpn-worker");
        worker.start();
    }

    private void runVpnOnce(String link, int generation) {
        try {
            if (link == null || link.trim().isEmpty()) throw new IllegalArgumentException("empty olcrtc link");
            OlcConfig config = OlcUriParser.parse(link);
            activeConfig = config;
            sessionStartedAtMs = System.currentTimeMillis();
            int tunnelMtu = mtuForTransport(config);
            Log.i(TAG, "Parsed config: " + config.pretty());
            sendStatus("Ссылка разобрана: " + config.carrier + " / " + transportLabel(config) + " / MTU " + tunnelMtu);

            if (!OlcMobileBridge.isAvailable()) {
                throw new IllegalStateException("combined mobile AAR not found. Run scripts/build_combo_aar.sh and rebuild APK");
            }
            if (!Tun2SocksMobileBridge.isAvailable()) {
                throw new IllegalStateException("combined mobile AAR has no StartTun2Socks. Rebuild app/libs/olcrtccombo.aar");
            }

            olc = new OlcMobileBridge();
            olc.setDebug(true);
            final int logGeneration = generation;
            olc.setLogWriter(new OlcMobileBridge.LogSink() {
                @Override
                public void writeLog(String message) {
                    handleOlcLog(message, logGeneration);
                }
            });
            olc.setProviders();
            olc.setProtector(this);

            String dnsCandidates = getPreTunnelDnsCandidates();
            String preTunnelDns = olc.setAutoDNS(dnsCandidates, "stream.wb.ru");
            String upstream = "";
            try { upstream = olc.getAutoDNSUpstream(); } catch (Throwable ignored) {}
            if (upstream == null || upstream.trim().isEmpty()) upstream = "unknown";

            String linkMode = resolveLinkMode(config);
            olc.setLink(linkMode);
            String dnsMsg = "Pre-tunnel DNS auto local=" + preTunnelDns + " upstream=" + upstream + " link=" + linkMode;
            Log.i(TAG, dnsMsg + " candidates=" + dnsCandidates);
            sendStatus(dnsMsg);

            sendStatus("Подключаю olcRTC " + config.transport + "...");
            if (isVideo(config)) {
                String ffmpegPath = AndroidVideoRuntime.prepare(this, config);
                olc.setFFmpegPath(ffmpegPath);
                sendStatus("Android video runtime ready: ffmpeg " + ffmpegPath);
            }
            olc.startWithConfig(config, SOCKS_PORT, "", "");
            // SEI needs its own, longer timeout because mtslink multipath bootstraps many lanes in parallel.
            int startupTimeout = isSei(config) ? SEI_STARTUP_TIMEOUT_MS
                    : (isVisualTransport(config) ? VP8_STARTUP_TIMEOUT_MS : STARTUP_TIMEOUT_MS);
            olc.waitReady(startupTimeout);
            sendStatus("olcRTC подключён. Проверяю локальный SOCKS 127.0.0.1:" + SOCKS_PORT);

            if (!waitForLocalSocksReady()) {
                throw new IllegalStateException("local SOCKS is not ready");
            }

            // VP8 and video need a short stabilise pause after WaitReady so the media pipeline
            // settles before the first SOCKS CONNECT. SEI's data channel is ready immediately
            // after WaitReady, so no pause is needed (and it would only waste time).
            if (needsRtcStabilize(config)) {
                if (isVp8(config) && vp8Batch(config) <= 1) {
                    sendStatus("VP8 batch=1: режим совместим с этой ссылкой, но для реального VPN лучше перезапустить server/link с vp8-batch=4 или 64.");
                }
                sendStatus("Жду стабилизацию RTC media-канала " + (VP8_STABILIZE_MS / 1000.0) + " сек...");
                try { Thread.sleep(VP8_STABILIZE_MS); } catch (InterruptedException ignored) {}
            }

            sendStatus("Проверяю, что серверная сторона olcRTC уже отвечает на CONNECT...");
            if (!waitForRemoteConnectReady(config)) {
                throw new IllegalStateException("olcRTC SOCKS слушает локально, но серверная сторона ещё не готова к CONNECT");
            }

            Builder builder = new Builder()
                    .setSession("olcRTC VPN")
                    .setMtu(tunnelMtu)
                    .addAddress("10.77.0.2", 24)
                    .addRoute("0.0.0.0", 0);

            String androidDnsPolicy = configureAndroidDnsPolicy(builder);

            try {
                builder.addDisallowedApplication(getPackageName());
                Log.i(TAG, "Excluded self package from VPN: " + getPackageName());
            } catch (Exception e) {
                Log.w(TAG, "Failed to exclude self package from VPN", e);
            }

            tunFd = builder.establish();
            if (tunFd == null) throw new IllegalStateException("VPN permission not granted or TUN establish failed");

            String tunnelDnsUpstream = chooseTunnelDnsUpstream(upstream);
            int tcpDialLimit = tcpDialLimitForTransport(config);
            int rawTunFd = tunFd.detachFd();
            tunFd = null;
            detachedTunFd = rawTunFd;
            tun2socks = new Tun2SocksMobileBridge();
            tun2socks.start(rawTunFd, "socks5://127.0.0.1:" + SOCKS_PORT, tunnelMtu, "info", tunnelDnsUpstream, tcpDialLimit);
            tunEstablished = true;
            startTelemetryTicker();

            reconnectAttempt = 0;
            startForegroundCompat("Connected");
            Log.i(TAG, "VPN connected");
            sendStatus("VPN connected\n" +
                    dnsMsg + "\n" +
                    androidDnsPolicy + "\n" +
                    "Local DNS hijack: " + tunnelDnsUpstream + " direct from Android app if DNS enters TUN\n" +
                    "Transport: " + transportLabel(config) + "\n" +
                    "MTU: " + tunnelMtu + "\n" +
                    "TCP start limiter: " + tcpDialLimit + " parallel dials\n" +
                    "UDP 443 / TCP 853: drop\n" +
                    "Keepalive: local SOCKS/core only every " + (KEEPALIVE_INTERVAL_MS / 1000) + "s");

            registerNetworkCallback();

            long lastKeepAliveAt = 0L;
            while (!stopRequested && generation == workerGeneration && !restartRequested) {
                try { Thread.sleep(5000); } catch (InterruptedException ignored) {}
                if (stopRequested || generation != workerGeneration || restartRequested) break;

                if (olc == null || !olc.isRunning()) {
                    throw new IllegalStateException("olcRTC core stopped / ICE failed");
                }

                long now = System.currentTimeMillis();
                if (now - lastKeepAliveAt >= KEEPALIVE_INTERVAL_MS) {
                    lastKeepAliveAt = now;
                    if (runLocalSocksHandshakeProbe(LOCAL_SOCKS_PROBE_TIMEOUT_MS)) {
                        keepAliveFailures = 0;
                        startForegroundCompat(notificationSpeedText());
                    } else {
                        keepAliveFailures++;
                        Log.w(TAG, "keepalive failed " + keepAliveFailures + "/" + KEEPALIVE_MAX_FAILURES);
                        sendStatus("Keepalive fail " + keepAliveFailures + "/" + KEEPALIVE_MAX_FAILURES);
                        if (keepAliveFailures >= KEEPALIVE_MAX_FAILURES) {
                            throw new IllegalStateException("keepalive failed " + KEEPALIVE_MAX_FAILURES + " times");
                        }
                    }
                }
            }
        } catch (Exception e) {
            if (generation != workerGeneration || restartRequested || controlledReconnectPending) {
                Log.i(TAG, "old worker stopped during controlled reconnect: " + e.getMessage());
                return;
            }
            Log.e(TAG, "VPN failed", e);
            sendStatus("Ошибка: " + e.getMessage());
            startForegroundCompat("Error: " + e.getMessage());
            shutdownResources();
            scheduleReconnectIfNeeded();
        }
    }

    private void scheduleReconnectIfNeeded() {
        if (stopRequested || currentLink == null || currentLink.trim().isEmpty()) {
            stopSelf();
            return;
        }
        reconnectAttempt++;
        int delayMs = Math.min(30000, 5000 + reconnectAttempt * 3000);
        final int scheduledGeneration;
        // Capture the generation under the same monitor that mutates it. Without
        // this lock another thread (scheduleControlledReconnect) could bump the
        // generation between the read and the post-sleep check, opening a race
        // where two workers start back-to-back.
        synchronized (lock) {
            scheduledGeneration = workerGeneration;
        }
        sendStatus("Автопереподключение через " + (delayMs / 1000) + " сек. Попытка #" + reconnectAttempt);
        new Thread(() -> {
            try { Thread.sleep(delayMs); } catch (InterruptedException ignored) {}
            synchronized (lock) {
                if (!stopRequested
                        && currentLink != null
                        && !currentLink.trim().isEmpty()
                        && !controlledReconnectPending
                        && workerGeneration == scheduledGeneration) {
                    startWorkerLocked(currentLink);
                }
            }
        }, "olcrtc-reconnect-delay").start();
    }

    private void registerNetworkCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return;
        unregisterNetworkCallback();

        connectivityManager = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        if (connectivityManager == null) return;

        ignoreNetworkEventsUntilMs = System.currentTimeMillis() + NETWORK_CALLBACK_IGNORE_MS;
        activeNetworkSignature = currentActiveNetworkSignature();
        networkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                maybeControlledReconnectForNetwork(network, "network available");
            }

            @Override
            public void onLost(Network network) {
                maybeControlledReconnectForNetwork(network, "network lost");
            }

            @Override
            public void onLinkPropertiesChanged(Network network, LinkProperties linkProperties) {
                maybeControlledReconnectForNetwork(network, "network link changed");
            }
        };

        try {
            NetworkRequest request = new NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build();
            connectivityManager.registerNetworkCallback(request, networkCallback);
            Log.i(TAG, "network callback registered");
        } catch (Throwable t) {
            Log.w(TAG, "failed to register network callback", t);
            networkCallback = null;
        }
    }

    private void unregisterNetworkCallback() {
        if (connectivityManager != null && networkCallback != null) {
            try { connectivityManager.unregisterNetworkCallback(networkCallback); } catch (Throwable ignored) {}
        }
        networkCallback = null;
    }

    private void maybeControlledReconnectForNetwork(Network network, String reason) {
        if (stopRequested || currentLink == null || currentLink.trim().isEmpty()) return;
        long now = System.currentTimeMillis();
        if (now < ignoreNetworkEventsUntilMs) return;
        if (isVpnNetwork(network)) return;

        String newSignature = currentActiveNetworkSignature();
        if (newSignature.equals(activeNetworkSignature)) {
            Log.i(TAG, "Ignoring network callback without active network switch: " + reason + " sig=" + newSignature);
            return;
        }
        activeNetworkSignature = newSignature;

        synchronized (lock) {
            if (now - lastNetworkReconnectAtMs < NETWORK_RECONNECT_DEBOUNCE_MS) return;
            lastNetworkReconnectAtMs = now;
        }

        scheduleControlledReconnect("Сеть изменилась: " + reason, NETWORK_RECONNECT_DELAY_MS, "olcrtc-network-reconnect");
    }

    private void scheduleControlledReconnect(String reason, long delayMs, String threadName) {
        if (stopRequested || currentLink == null || currentLink.trim().isEmpty()) return;
        final int scheduledGeneration;
        synchronized (lock) {
            if (controlledReconnectPending) return;
            controlledReconnectPending = true;
            restartRequested = true;
            tunEstablished = false;
            stopTelemetryTicker();
            workerGeneration++;
            scheduledGeneration = workerGeneration;
        }

        sendStatus(reason + ". Полностью пересоздаю olcRTC через " + (delayMs / 1000) + " сек...");

        new Thread(() -> {
            boolean reconnectHandedOff = false;
            try {
                if (stopRequested || workerGeneration != scheduledGeneration) return;
                shutdownResources();
                try { Thread.sleep(delayMs); } catch (InterruptedException ignored) {}

                String linkToStart = null;
                synchronized (lock) {
                    if (!stopRequested && currentLink != null && workerGeneration == scheduledGeneration) {
                        linkToStart = currentLink;
                        controlledReconnectPending = false;
                        reconnectHandedOff = true;
                    }
                }

                if (linkToStart != null) {
                    sendStatus("Переподключаюсь...");
                    startWorker(linkToStart);
                }
            } finally {
                if (!reconnectHandedOff) {
                    synchronized (lock) {
                        if (workerGeneration == scheduledGeneration) controlledReconnectPending = false;
                    }
                }
            }
        }, threadName).start();
    }

    private String currentActiveNetworkSignature() {
        try {
            ConnectivityManager cm = connectivityManager != null
                    ? connectivityManager
                    : (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
            if (cm == null) return "no-cm";
            Network active = cm.getActiveNetwork();
            if (active == null) return "no-active";
            NetworkCapabilities caps = cm.getNetworkCapabilities(active);
            StringBuilder sb = new StringBuilder(active.toString());
            if (caps != null) {
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) sb.append("/wifi");
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) sb.append("/cell");
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) sb.append("/eth");
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) sb.append("/vpn");
            }
            return sb.toString();
        } catch (Throwable t) {
            return "unknown";
        }
    }

    private boolean isVpnNetwork(Network network) {
        if (network == null || connectivityManager == null) return false;
        try {
            NetworkCapabilities caps = connectivityManager.getNetworkCapabilities(network);
            return caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN);
        } catch (Throwable ignored) {
            return false;
        }
    }

    private void handleOlcLog(String raw, int generation) {
        if (raw == null) return;
        String msg = raw.trim();
        if (msg.isEmpty()) return;
        Log.d("OlcCore", msg);
        if (generation != workerGeneration || stopRequested) return;

        boolean reconnectLine = msg.contains("client link reconnect") || msg.contains("tearing down smux session");
        boolean remoteNotReadyLine = msg.contains("remote not ready")
                || msg.contains("CONNECT: host unreachable")
                || msg.contains("read/write on closed pipe")
                || msg.contains("OpenStream failed");
        if (!reconnectLine && !remoteNotReadyLine) return;

        long now = System.currentTimeMillis();
        boolean shouldRestart = false;
        synchronized (lock) {
            if (now - lastOlcStormWindowStartMs > OLC_STORM_WINDOW_MS) {
                lastOlcStormWindowStartMs = now;
                olcStormEvents = 0;
                olcRemoteReadyEvents = 0;
            }
            if (reconnectLine) olcStormEvents++;
            if (remoteNotReadyLine) olcRemoteReadyEvents++;

            boolean storm = olcStormEvents >= OLC_STORM_RECONNECT_THRESHOLD
                    || olcRemoteReadyEvents >= OLC_STORM_REMOTE_READY_THRESHOLD;
            if (tunEstablished && storm && now - lastCoreReconnectAtMs > OLC_STORM_WINDOW_MS && !controlledReconnectPending) {
                lastCoreReconnectAtMs = now;
                shouldRestart = true;
                olcStormEvents = 0;
                olcRemoteReadyEvents = 0;
            }
        }

        if (shouldRestart) {
            scheduleControlledReconnect("olcRTC media/data канал нестабилен: много remote-not-ready/reconnect подряд", CORE_RECONNECT_DELAY_MS, "olcrtc-core-storm-reconnect");
        }
    }

    private String resolveLinkMode(OlcConfig config) {
        String fromParam = config == null ? null : config.param("link", null);
        if (fromParam != null && !fromParam.trim().isEmpty()) return fromParam.trim().toLowerCase();

        String comment = config == null ? null : config.comment;
        if (isKnownLinkMode(comment)) return comment.trim().toLowerCase();

        // In official olcRTC URIs, the $ part is usually a human comment like
        // "OLC chat - t.me/...", not the -link value. Passing that into SetLink()
        // breaks carrier setup. The Android client should default to direct.
        if (comment != null && !comment.trim().isEmpty()) {
            Log.i(TAG, "Ignoring URI comment as link mode: " + comment);
        }
        return "direct";
    }

    private boolean isKnownLinkMode(String value) {
        if (value == null) return false;
        String v = value.trim().toLowerCase();
        return "direct".equals(v);
    }

    private boolean isVp8(OlcConfig config) {
        return config != null && OlcUriParser.TRANSPORT_VP8.equals(config.transport);
    }

    private boolean isSei(OlcConfig config) {
        return config != null && OlcUriParser.TRANSPORT_SEI.equals(config.transport);
    }

    private boolean isVideo(OlcConfig config) {
        return config != null && OlcUriParser.TRANSPORT_VIDEO.equals(config.transport);
    }

    /** Returns true for transports that use a live video media track (VP8 / video codec). */
    private boolean isVisualTransport(OlcConfig config) {
        return isVp8(config) || isVideo(config);
    }

    /**
     * Returns true when the transport needs a brief post-WaitReady pause to let the WebRTC
     * media pipeline settle before the first SOCKS CONNECT goes out.
     * VP8 / video use a live media track and benefit from this delay.
     * SEI uses a data channel that is immediately usable after WaitReady.
     */
    private boolean needsRtcStabilize(OlcConfig config) {
        return isVp8(config) || isVideo(config);
    }

    private int mtuForTransport(OlcConfig config) {
        // SEI runs over a data channel and can handle full Ethernet MTU; only real video
        // transports need the reduced VP8_MTU to avoid carrier fragmentation pain.
        int fallback = isVisualTransport(config) ? VP8_MTU : DATA_MTU;
        int requested = config == null ? fallback : config.intParam("mtu", fallback);
        return clampInt(requested, 900, DATA_MTU);
    }

    private int tcpDialLimitForTransport(OlcConfig config) {
        // SEI + datachannel can easily sustain 8 parallel TCP dials just like datachannel.
        // Only visual transports (VP8/video) need the stricter 2-dial limit.
        int fallback = isVisualTransport(config) ? VP8_TCP_DIAL_LIMIT : DATA_TCP_DIAL_LIMIT;
        int requested = config == null ? fallback : config.intParam("tcp-limit", fallback);
        return clampInt(requested, 1, 32);
    }

    private int vp8Fps(OlcConfig config) {
        return config == null ? 25 : config.intParam("vp8-fps", config.intParam("fps", 25));
    }

    private int vp8Batch(OlcConfig config) {
        return config == null ? 1 : config.intParam("vp8-batch", config.intParam("batch", 1));
    }

    private int seiFps(OlcConfig config) {
        return config == null ? 30 : config.intParam("fps", config.intParam("sei-fps", 30));
    }

    private int seiBatch(OlcConfig config) {
        // Aligned with mobile.go defaults (seiBatchSize=8): both mtslink and other
        // carriers must agree on batch size, otherwise Go and Java drift apart
        // (Android could send 64 frames per tick while Go expects 8).
        return config == null ? 8 : config.intParam("batch", config.intParam("sei-batch", 8));
    }

    private int seiFrag(OlcConfig config) {
        // Aligned with mobile.go default seiFragmentSize=700.
        return config == null ? 700 : config.intParam("frag", config.intParam("sei-frag", 700));
    }

    private int seiAckMs(OlcConfig config) {
        // Aligned with mobile.go default seiAckTimeoutMS=10000.
        return config == null ? 10000 : config.intParam("ack-ms", config.intParam("sei-ack-ms", 10000));
    }

    private int clampInt(int value, int min, int max) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    private String transportLabel(OlcConfig config) {
        if (config == null) return "unknown";
        if (isVp8(config)) {
            return config.transport + " <vp8-fps=" + vp8Fps(config) + ", vp8-batch=" + vp8Batch(config) + ">";
        }
        if (isSei(config)) {
            int lanes = config.intParam("mc-lanes", config.intParam("sei-lanes", config.intParam("lanes", 1)));
            String laneLabel = lanes > 1 ? ", lanes=" + lanes : "";
            return config.transport + " <fps=" + seiFps(config) + ", batch=" + seiBatch(config) + ", frag=" + seiFrag(config) + ", ack-ms=" + seiAckMs(config) + laneLabel + ">";
        }
        if (isVideo(config)) {
            boolean isMtsLink = "mtslink".equalsIgnoreCase(config.carrier);
            String codec = config.param("video-codec", "qrcode");
            int w = config.intParam("video-w", config.intParam("video-width", isMtsLink ? 640 : 1080));
            int h = config.intParam("video-h", config.intParam("video-height", isMtsLink ? 360 : 1080));
            int fps = config.intParam("video-fps", isMtsLink ? 15 : 60);
            String bitrate = config.param("video-bitrate", isMtsLink ? "1200k" : "5000k");
            return config.transport + " <codec=" + codec + ", " + w + "x" + h + ", fps=" + fps + ", bitrate=" + bitrate + ">";
        }
        return config.transport;
    }

    private boolean waitForRemoteConnectReady(OlcConfig config) {
        // VP8 and SEI both use many probes; datachannel converges quickly so fewer are needed.
        // SEI multipath may still be routing through a freshly-opened lane on the first try.
        int attempts = (isVisualTransport(config) || isSei(config)) ? VP8_REMOTE_PROBE_ATTEMPTS : DATA_REMOTE_PROBE_ATTEMPTS;
        // Between probes: for VP8/video give the media pipeline breathing room; SEI/data can
        // retry sooner since the underlying channel is already up.
        long probeIntervalMs = isVisualTransport(config) ? 1200 : 700;
        for (int i = 1; i <= attempts && !stopRequested; i++) {
            for (String target : REMOTE_CONNECT_PROBE_TARGETS) {
                if (runLocalSocksConnectProbe(target, REMOTE_PROBE_TIMEOUT_MS)) {
                    sendStatus("Remote CONNECT OK через olcRTC: " + target);
                    return true;
                }
            }
            sendStatus("Remote CONNECT ещё не готов " + i + "/" + attempts + ". Жду без запуска TUN...");
            try { Thread.sleep(probeIntervalMs); } catch (InterruptedException ignored) {}
        }
        return false;
    }

    private boolean runLocalSocksConnectProbe(String hostPort, int timeoutMs) {
        String host = hostPort;
        int port = 443;
        int colon = hostPort == null ? -1 : hostPort.lastIndexOf(':');
        if (colon > 0 && colon + 1 < hostPort.length()) {
            host = hostPort.substring(0, colon);
            try { port = Integer.parseInt(hostPort.substring(colon + 1)); } catch (Exception ignored) { port = 443; }
        }

        Socket socket = null;
        try {
            socket = new Socket();
            socket.connect(new InetSocketAddress("127.0.0.1", SOCKS_PORT), Math.max(1000, timeoutMs));
            socket.setSoTimeout(Math.max(1000, timeoutMs));
            InputStream in = socket.getInputStream();
            OutputStream out = socket.getOutputStream();

            out.write(new byte[]{0x05, 0x01, 0x00});
            out.flush();
            byte[] greeting = readExactly(in, 2);
            if (greeting[0] != 0x05 || greeting[1] != 0x00) return false;

            byte[] ip = InetAddress.getByName(host).getAddress();
            if (ip.length != 4) return false;
            byte[] req = new byte[10];
            req[0] = 0x05;
            req[1] = 0x01;
            req[2] = 0x00;
            req[3] = 0x01;
            System.arraycopy(ip, 0, req, 4, 4);
            req[8] = (byte) ((port >> 8) & 0xff);
            req[9] = (byte) (port & 0xff);
            out.write(req);
            out.flush();

            byte[] head = readExactly(in, 4);
            int rep = head[1] & 0xff;
            int atyp = head[3] & 0xff;
            int rest = 0;
            if (atyp == 0x01) rest = 4 + 2;
            else if (atyp == 0x03) {
                byte[] len = readExactly(in, 1);
                rest = (len[0] & 0xff) + 2;
            } else if (atyp == 0x04) rest = 16 + 2;
            if (rest > 0) readExactly(in, rest);
            if (rep == 0x00) return true;
            Log.w(TAG, "remote SOCKS CONNECT probe failed target=" + hostPort + " rep=" + rep);
            return false;
        } catch (Throwable t) {
            Log.w(TAG, "remote SOCKS CONNECT probe error target=" + hostPort, t);
            return false;
        } finally {
            if (socket != null) {
                try { socket.close(); } catch (Exception ignored) {}
            }
        }
    }

    private boolean waitForLocalSocksReady() {
        for (int i = 1; i <= LOCAL_SOCKS_PROBE_ATTEMPTS && !stopRequested; i++) {
            if (runLocalSocksHandshakeProbe(LOCAL_SOCKS_PROBE_TIMEOUT_MS)) return true;
            sendStatus("Локальный SOCKS ещё не готов " + i + "/" + LOCAL_SOCKS_PROBE_ATTEMPTS + ". Жду...");
            try { Thread.sleep(500); } catch (InterruptedException ignored) {}
        }
        return false;
    }

    private boolean runLocalSocksHandshakeProbe(int timeoutMs) {
        long startedAt = System.currentTimeMillis();
        Socket socket = null;
        try {
            socket = new Socket();
            socket.connect(new InetSocketAddress("127.0.0.1", SOCKS_PORT), Math.max(1000, timeoutMs));
            socket.setSoTimeout(Math.max(1000, timeoutMs));
            InputStream in = socket.getInputStream();
            OutputStream out = socket.getOutputStream();
            out.write(new byte[]{0x05, 0x01, 0x00});
            out.flush();
            byte[] greeting = readExactly(in, 2);
            boolean ok = greeting[0] == 0x05 && greeting[1] == 0x00;
            lastProbeLatencyMs = ok ? Math.max(0L, System.currentTimeMillis() - startedAt) : -1L;
            return ok;
        } catch (Throwable t) {
            lastProbeLatencyMs = -1L;
            Log.w(TAG, "local SOCKS probe failed", t);
            return false;
        } finally {
            if (socket != null) {
                try { socket.close(); } catch (Exception ignored) {}
            }
        }
    }

    private byte[] readExactly(InputStream in, int len) throws Exception {
        byte[] out = new byte[len];
        int off = 0;
        while (off < len) {
            int n = in.read(out, off, len - off);
            if (n < 0) throw new IllegalStateException("unexpected EOF");
            off += n;
        }
        return out;
    }

    private String configureAndroidDnsPolicy(Builder builder) {
        List<String> dnsServers = new ArrayList<>();
        for (String dns : PUBLIC_VPN_DNS) addIfMissing(dnsServers, dns);

        for (String dns : dnsServers) {
            try {
                builder.addDnsServer(dns);
            } catch (Exception e) {
                Log.w(TAG, "Failed to add Android DNS server " + dns, e);
            }
        }

        int excluded = 0;
        if (Build.VERSION.SDK_INT >= 33) {
            List<String> excludeHosts = new ArrayList<>(dnsServers);
            for (String ip : EXTRA_DNS_ROUTE_EXCLUDES) addIfMissing(excludeHosts, ip);
            for (String ip : excludeHosts) {
                try {
                    builder.excludeRoute(new IpPrefix(InetAddress.getByName(ip), 32));
                    excluded++;
                } catch (Exception e) {
                    Log.w(TAG, "Failed to exclude DNS route " + ip, e);
                }
            }
        }

        if (excluded > 0) {
            return "Android DNS direct-bypass: " + String.join(" / ", dnsServers) + ", excluded routes=" + excluded;
        }
        return "Android DNS: public DNS via TUN/AAR hijack fallback " + String.join(" / ", dnsServers);
    }

    private String chooseTunnelDnsUpstream(String upstream) {
        String fromUpstream = extractPublicDnsHostPort(upstream);
        if (fromUpstream != null) return fromUpstream;
        return TUNNEL_DNS_CLOUDFLARE;
    }

    private String extractPublicDnsHostPort(String upstream) {
        if (upstream == null) return null;
        String u = upstream.trim();
        if (u.isEmpty() || "unknown".equalsIgnoreCase(u)) return null;
        if (u.startsWith("udp:")) u = u.substring(4).trim();
        if (u.startsWith("fallback-direct:")) u = u.substring("fallback-direct:".length()).trim();
        if (u.startsWith("doh:")) {
            int at = u.lastIndexOf('@');
            if (at < 0 || at + 1 >= u.length()) return null;
            u = u.substring(at + 1).trim();
        }
        if (!isPublicDnsAddress(u)) return null;
        String normalized = normalizePublicDnsWithPort(u);
        if (isCloudflareDns(normalized)) return TUNNEL_DNS_CLOUDFLARE;
        if (isGoogleDns(normalized)) return TUNNEL_DNS_GOOGLE;
        if (isYandexDns(normalized)) return TUNNEL_DNS_YANDEX;
        return normalized;
    }

    private String normalizePublicDnsWithPort(String value) {
        if (value == null) return TUNNEL_DNS_CLOUDFLARE;
        String v = value.trim();
        if (v.isEmpty()) return TUNNEL_DNS_CLOUDFLARE;
        if (v.startsWith("[") && v.contains("]:")) return v;
        if (v.startsWith("[") && v.endsWith("]")) return v + ":53";
        if (v.indexOf(':') < 0) return v + ":53";
        int lastColon = v.lastIndexOf(':');
        if (lastColon > 0 && v.substring(lastColon + 1).matches("\\d+")) return v;
        return "[" + v + "]:53";
    }

    private boolean isCloudflareDns(String value) {
        String h = stripDnsPort(value);
        return "1.1.1.1".equals(h) || "1.0.0.1".equals(h) || "2606:4700:4700::1111".equalsIgnoreCase(h) || "2606:4700:4700::1001".equalsIgnoreCase(h);
    }

    private boolean isGoogleDns(String value) {
        String h = stripDnsPort(value);
        return "8.8.8.8".equals(h) || "8.8.4.4".equals(h) || "2001:4860:4860::8888".equalsIgnoreCase(h) || "2001:4860:4860::8844".equalsIgnoreCase(h);
    }

    private boolean isYandexDns(String value) {
        String h = stripDnsPort(value);
        return "77.88.8.8".equals(h) || "77.88.8.1".equals(h) || "2a02:6b8::feed:0ff".equalsIgnoreCase(h) || "2a02:6b8:0:1::feed:0ff".equalsIgnoreCase(h);
    }

    private String stripDnsPort(String value) {
        if (value == null) return "";
        String host = value.trim();
        if (host.startsWith("[") && host.contains("]")) return host.substring(1, host.indexOf(']'));
        if (host.contains(":")) {
            int lastColon = host.lastIndexOf(':');
            String maybePort = host.substring(lastColon + 1);
            if (maybePort.matches("\\d+")) return host.substring(0, lastColon);
        }
        return host;
    }

    private boolean isPublicDnsAddress(String value) {
        if (value == null) return false;
        String host = value.trim();
        if (host.isEmpty()) return false;
        if (host.startsWith("[") && host.contains("]")) {
            host = host.substring(1, host.indexOf(']'));
        } else if (host.contains(":")) {
            int lastColon = host.lastIndexOf(':');
            String maybePort = host.substring(lastColon + 1);
            if (maybePort.matches("\\d+")) host = host.substring(0, lastColon);
        }

        try {
            InetAddress addr = InetAddress.getByName(host);
            if (addr.isAnyLocalAddress() || addr.isLoopbackAddress() || addr.isLinkLocalAddress() || addr.isSiteLocalAddress()) return false;
            byte[] b = addr.getAddress();
            if (b.length == 4) {
                int a = b[0] & 0xff;
                int c = b[1] & 0xff;
                if (a == 100 && c >= 64 && c <= 127) return false;
                if (a >= 224 || a == 0) return false;
            }
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    private String getPreTunnelDnsCandidates() {
        List<String> dns = new ArrayList<>();

        try {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
            if (cm != null) {
                Network network = cm.getActiveNetwork();
                LinkProperties props = cm.getLinkProperties(network);
                if (props != null) {
                    for (InetAddress server : props.getDnsServers()) {
                        String normalized = normalizeDnsForCombo(server);
                        if (normalized != null && !dns.contains(normalized)) dns.add(normalized);
                    }
                }
            }
        } catch (Throwable t) {
            Log.w(TAG, "failed to read system DNS, using fallback candidates", t);
        }

        addIfMissing(dns, "77.88.8.8:53");
        addIfMissing(dns, "77.88.8.1:53");
        addIfMissing(dns, "1.1.1.1:53");
        addIfMissing(dns, "8.8.8.8:53");
        addIfMissing(dns, "doh:https://common.dot.dns.yandex.net/dns-query@77.88.8.8");
        addIfMissing(dns, "doh:https://cloudflare-dns.com/dns-query@1.1.1.1");
        addIfMissing(dns, "doh:https://dns.google/dns-query@8.8.8.8");

        String joined = String.join(",", dns);
        Log.i(TAG, "pre-tunnel DNS candidates=" + joined);
        return joined;
    }

    private String normalizeDnsForCombo(InetAddress dns) {
        if (dns == null || dns.isLoopbackAddress() || dns.isAnyLocalAddress()) return null;
        String host = dns.getHostAddress();
        if (host == null || host.trim().isEmpty()) return null;
        if (host.contains("%")) host = host.substring(0, host.indexOf('%'));
        if (host.contains(":")) return "[" + host + "]:53";
        return host + ":53";
    }

    private void addIfMissing(List<String> list, String value) {
        if (value != null && !list.contains(value)) list.add(value);
    }

    private long currentUidRxBytes() {
        long value = TrafficStats.getUidRxBytes(getApplicationInfo().uid);
        return value == TrafficStats.UNSUPPORTED ? -1L : value;
    }

    private long currentUidTxBytes() {
        long value = TrafficStats.getUidTxBytes(getApplicationInfo().uid);
        return value == TrafficStats.UNSUPPORTED ? -1L : value;
    }

    private void updateTelemetrySnapshot() {
        long now = System.currentTimeMillis();
        long rx = currentUidRxBytes();
        long tx = currentUidTxBytes();
        if (rx < 0 || tx < 0) return;

        if (trafficBaseRx < 0 || trafficBaseTx < 0) {
            trafficBaseRx = rx;
            trafficBaseTx = tx;
            trafficLastRx = rx;
            trafficLastTx = tx;
            trafficLastAtMs = now;
            return;
        }

        sessionRxBytes = Math.max(0L, rx - trafficBaseRx);
        sessionTxBytes = Math.max(0L, tx - trafficBaseTx);

        if (trafficLastAtMs > 0 && now > trafficLastAtMs && trafficLastRx >= 0 && trafficLastTx >= 0) {
            long elapsedMs = Math.max(1L, now - trafficLastAtMs);
            rxBps = Math.max(0L, (rx - trafficLastRx) * 1000L / elapsedMs);
            txBps = Math.max(0L, (tx - trafficLastTx) * 1000L / elapsedMs);
        }
        trafficLastRx = rx;
        trafficLastTx = tx;
        trafficLastAtMs = now;
    }

    private String telemetryState() {
        if (stopRequested || (currentLink == null && activeConfig == null && !tunEstablished)) return "disconnected";
        if (tunEstablished) return "connected";
        if (restartRequested || controlledReconnectPending) return "reconnecting";
        if (activeConfig != null || worker != null) return "connecting";
        return "disconnected";
    }

    private int activeLaneCount(OlcConfig config) {
        if (config == null) return 1;
        if (!OlcUriParser.TRANSPORT_SEI.equalsIgnoreCase(config.transport)) return 1;
        return Math.max(1, config.intParam("mc-lanes", config.intParam("sei-lanes", config.intParam("lanes", 1))));
    }

    private String notificationSpeedText() {
        updateTelemetrySnapshot();
        if (!tunEstablished) return telemetryState();
        return "↓ " + formatRate(rxBps) + "  ↑ " + formatRate(txBps);
    }

    private String formatRate(long bps) {
        double value = Math.max(0L, bps);
        if (value >= 1024 * 1024) return String.format(java.util.Locale.US, "%.1f MB/s", value / 1024d / 1024d);
        if (value >= 1024) return String.format(java.util.Locale.US, "%.0f KB/s", value / 1024d);
        return Math.round(value) + " B/s";
    }

    private void sendStatus(String status) {
        updateTelemetrySnapshot();
        lastStatusSnapshot = status == null ? "" : status;
        Log.i(TAG, "STATUS: " + status);
        Intent intent = new Intent(ACTION_STATUS);
        intent.setPackage(getPackageName());
        intent.putExtra(EXTRA_STATUS, status);
        intent.putExtra(EXTRA_EVENT, status);
        intent.putExtra(EXTRA_STATE, telemetryState());
        OlcConfig config = activeConfig;
        intent.putExtra(EXTRA_CARRIER, config == null ? "" : config.carrier);
        intent.putExtra(EXTRA_TRANSPORT, config == null ? "" : config.transport);
        intent.putExtra(EXTRA_LANES, activeLaneCount(config));
        intent.putExtra(EXTRA_UPTIME_MS, sessionStartedAtMs > 0 ? Math.max(0L, System.currentTimeMillis() - sessionStartedAtMs) : 0L);
        intent.putExtra(EXTRA_SESSION_RX_BYTES, sessionRxBytes);
        intent.putExtra(EXTRA_SESSION_TX_BYTES, sessionTxBytes);
        intent.putExtra(EXTRA_RX_BPS, rxBps);
        intent.putExtra(EXTRA_TX_BPS, txBps);
        intent.putExtra(EXTRA_PROBE_LATENCY_MS, lastProbeLatencyMs);
        sendBroadcast(intent);
    }

    private void startForegroundCompat(String text) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "olcRTC VPN", NotificationManager.IMPORTANCE_LOW);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(channel);
        }

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);

        Intent openIntent = new Intent(this, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingFlags |= PendingIntent.FLAG_IMMUTABLE;
        }
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0, openIntent, pendingFlags);

        Notification notification = builder
                .setContentTitle("olcRTC VPN")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .build();

        startForeground(NOTIFICATION_ID, notification);
    }

    private void shutdownResources() {
        synchronized (lock) {
            shutdownResourcesLocked();
        }
    }

    private void shutdownResourcesLocked() {
        tunEstablished = false;
        stopTelemetryTicker();
        unregisterNetworkCallback();
        if (tun2socks != null) {
            tun2socks.stop();
            tun2socks = null;
        }
        if (olc != null) {
            olc.stop();
            olc = null;
        }
        if (tunFd != null) {
            try { tunFd.close(); } catch (Exception ignored) {}
            tunFd = null;
        }
        // If TUN fd was detached, Java no longer owns it. The native tun2socks
        // engine owns/closes it after StopTun2Socks. Closing it here can trigger
        // Android fdsan crashes: "fd is owned by ParcelFileDescriptor".
        detachedTunFd = -1;
    }

    private void resetSessionTelemetryLocked() {
        activeConfig = null;
        sessionStartedAtMs = 0L;
        trafficBaseRx = currentUidRxBytes();
        trafficBaseTx = currentUidTxBytes();
        trafficLastRx = trafficBaseRx;
        trafficLastTx = trafficBaseTx;
        trafficLastAtMs = System.currentTimeMillis();
        sessionRxBytes = 0L;
        sessionTxBytes = 0L;
        rxBps = 0L;
        txBps = 0L;
        lastProbeLatencyMs = -1L;
    }

    @Override
    public void onDestroy() {
        stopRequested = true;
        shutdownResources();
        synchronized (lock) {
            resetSessionTelemetryLocked();
        }
        sendStatus("Отключено.");
        super.onDestroy();
    }
}
