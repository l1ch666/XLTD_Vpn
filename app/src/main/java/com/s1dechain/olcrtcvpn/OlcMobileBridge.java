package com.s1dechain.olcrtcvpn;

import android.net.VpnService;
import android.util.Log;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.concurrent.atomic.AtomicInteger;

public final class OlcMobileBridge {
    private static final String TAG = "OlcMobileBridge";

    public interface LogSink {
        void writeLog(String message);
    }

    private final Class<?> mobileClass;

    public OlcMobileBridge() throws ClassNotFoundException {
        // gomobile bind usually exposes Go package "mobile" as Java package "mobile" and class "Mobile".
        this.mobileClass = Class.forName("mobile.Mobile");
    }

    public static boolean isAvailable() {
        try {
            Class.forName("mobile.Mobile");
            return true;
        } catch (Throwable ignored) {
            return false;
        }
    }

    public void setDebug(boolean enabled) throws Exception {
        callVoid(new String[]{"SetDebug", "setDebug"}, new Class<?>[]{boolean.class}, enabled);
    }

    public void setProviders() throws Exception {
        callVoid(new String[]{"SetProviders", "setProviders"}, new Class<?>[]{}, new Object[]{});
    }

    public void setDNS(String dnsServer) throws Exception {
        callVoid(new String[]{"SetDNS", "setDNS"}, new Class<?>[]{String.class}, dnsServer);
    }

    public String setAutoDNS(String candidatesCsv, String probeHost) throws Exception {
        Method method = findMethod(
                new String[]{"SetAutoDNS", "setAutoDNS"},
                new Class<?>[]{String.class, String.class}
        );
        try {
            Object result = method.invoke(null, candidatesCsv, probeHost);
            return result == null ? "" : result.toString();
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof Exception) throw (Exception) cause;
            if (cause instanceof Error) throw (Error) cause;
            throw new RuntimeException(cause);
        }
    }

    public void setLink(String linkMode) throws Exception {
        callVoid(new String[]{"SetLink", "setLink"}, new Class<?>[]{String.class}, linkMode);
    }

    public void setFFmpegPath(String path) throws Exception {
        if (path == null || path.trim().isEmpty()) return;
        try {
            callVoid(new String[]{"SetFFmpegPath", "setFFmpegPath"}, new Class<?>[]{String.class}, path.trim());
        } catch (NoSuchMethodException ignored) {
            throw new IllegalStateException("combo AAR has no SetFFmpegPath; rebuild app/libs/olcrtccombo.aar");
        }
    }

    public String getAutoDNSUpstream() throws Exception {
        Method method = findMethod(
                new String[]{"GetAutoDNSUpstream", "getAutoDNSUpstream"},
                new Class<?>[]{}
        );
        try {
            Object result = method.invoke(null);
            return result == null ? "" : result.toString();
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof Exception) throw (Exception) cause;
            if (cause instanceof Error) throw (Error) cause;
            throw new RuntimeException(cause);
        }
    }

    public void setLogWriter(final LogSink sink) throws Exception {
        if (sink == null) return;
        final Class<?> writerInterface;
        try {
            writerInterface = Class.forName("mobile.LogWriter");
        } catch (ClassNotFoundException ignored) {
            return;
        }

        InvocationHandler handler = (proxy, method, args) -> {
            String name = method.getName();
            if (("WriteLog".equals(name) || "writeLog".equals(name)) && args != null && args.length > 0) {
                sink.writeLog(String.valueOf(args[0]));
                return null;
            }
            if (method.getReturnType() == boolean.class) return false;
            if (method.getReturnType() == int.class || method.getReturnType() == long.class) return 0;
            return null;
        };

        Object proxy = Proxy.newProxyInstance(
                writerInterface.getClassLoader(),
                new Class<?>[]{writerInterface},
                handler
        );

        try {
            callVoid(new String[]{"SetLogWriter", "setLogWriter"}, new Class<?>[]{writerInterface}, proxy);
        } catch (NoSuchMethodException ignored) {
            // Older AAR: Android logcat still receives gomobile logs; no hard failure.
        }
    }

    public void setProtector(final VpnService service) throws Exception {
        Class<?> protectorInterface = Class.forName("mobile.SocketProtector");
        final AtomicInteger protectCalls = new AtomicInteger(0);
        final AtomicInteger protectFailures = new AtomicInteger(0);
        InvocationHandler handler = (proxy, method, args) -> {
            if (method.getName().equalsIgnoreCase("Protect")) {
                int fd = ((Number) args[0]).intValue();
                boolean ok = service.protect(fd);
                int call = protectCalls.incrementAndGet();
                if (!ok) {
                    int fail = protectFailures.incrementAndGet();
                    Log.w(TAG, "VpnService.protect failed fd=" + fd + " failures=" + fail + " calls=" + call);
                } else if (call <= 5 || call % 100 == 0) {
                    Log.i(TAG, "VpnService.protect ok fd=" + fd + " calls=" + call);
                }
                return ok;
            }
            if (method.getReturnType() == boolean.class) return false;
            return null;
        };

        Object proxy = Proxy.newProxyInstance(
                protectorInterface.getClassLoader(),
                new Class<?>[]{protectorInterface},
                handler
        );

        callVoid(new String[]{"SetProtector", "setProtector"}, new Class<?>[]{protectorInterface}, proxy);
    }

    public void startWithConfig(
            OlcConfig config,
            int socksPort,
            String socksUser,
            String socksPass
    ) throws Exception {
        if (config == null) throw new IllegalArgumentException("empty config");
        if (!OlcUriParser.isSupportedTransport(config.transport)) {
            throw new IllegalArgumentException("unsupported transport in Android build: " + config.transport);
        }
        String transport = config.transport;
        boolean transportApplied = setTransportIfAvailable(transport);
        applyTransportOptions(config);

        startMobileApi(
                config.carrier,
                transport,
                transportApplied,
                config.roomId,
                config.clientId,
                config.keyHex,
                socksPort,
                socksUser,
                socksPass
        );
    }


    private void applyTransportOptions(OlcConfig config) throws Exception {
        if (config == null) return;
        String transport = config.transport;
        if (OlcUriParser.TRANSPORT_VP8.equals(transport)) {
            int vp8Fps = config.intParam("vp8-fps", config.intParam("fps", 25));
            int vp8Batch = config.intParam("vp8-batch", config.intParam("batch", 1));
            setVP8OptionsIfAvailable(vp8Fps, vp8Batch);
            return;
        }
        if (OlcUriParser.TRANSPORT_SEI.equals(transport)) {
            boolean isMtsLink = "mtslink".equalsIgnoreCase(config.carrier);
            int fps = config.intParam("fps", config.intParam("sei-fps", isMtsLink ? 30 : 60));
            int batch = config.intParam("batch", config.intParam("sei-batch", isMtsLink ? 8 : 64));
            int frag = config.intParam("frag", config.intParam("sei-frag", isMtsLink ? 700 : 900));
            int ackMs = config.intParam("ack-ms", config.intParam("sei-ack-ms", isMtsLink ? 10000 : 2000));
            setSEIOptionsIfAvailable(fps, batch, frag, ackMs);
            applyCarrierRuntimeOptions(config);
            return;
        }
        if (OlcUriParser.TRANSPORT_VIDEO.equals(transport)) {
            boolean isMtsLink = "mtslink".equalsIgnoreCase(config.carrier);
            String codec = config.param("video-codec", "qrcode");
            int width = config.intParam("video-w", config.intParam("video-width", isMtsLink ? 640 : 1080));
            int height = config.intParam("video-h", config.intParam("video-height", isMtsLink ? 360 : 1080));
            int fps = config.intParam("video-fps", isMtsLink ? 15 : 60);
            String bitrate = config.param("video-bitrate", isMtsLink ? "1200k" : "5000k");
            String hw = config.param("video-hw", "none");
            String qrRecovery = config.param("video-qr-recovery", "low");
            int qrSize = config.intParam("video-qr-size", 0);
            int tileModule = config.intParam("video-tile-module", 4);
            int tileRS = config.intParam("video-tile-rs", 20);
            setVideoOptionsIfAvailable(codec, width, height, fps, bitrate, hw, qrRecovery, qrSize, tileModule, tileRS);
            applyCarrierRuntimeOptions(config);
            return;
        }
        applyCarrierRuntimeOptions(config);
    }

    private boolean setTransportIfAvailable(String transport) throws Exception {
        try {
            callVoid(new String[]{"SetTransport", "setTransport"}, new Class<?>[]{String.class}, transport);
            return true;
        } catch (NoSuchMethodException ignored) {
            return false;
        }
    }

    private void setVP8OptionsIfAvailable(int fps, int batchSize) throws Exception {
        try {
            callVoid(new String[]{"SetVP8Options", "setVP8Options"}, new Class<?>[]{int.class, int.class}, fps, batchSize);
            return;
        } catch (NoSuchMethodException first) {
            try {
                callVoid(new String[]{"SetVP8Options", "setVP8Options"}, new Class<?>[]{long.class, long.class}, (long) fps, (long) batchSize);
            } catch (NoSuchMethodException ignored) {
                // Older AARs may not expose VP8 tuning. StartWithTransport/SetTransport still enables vp8channel.
            }
        }
    }


    private void setSEIOptionsIfAvailable(int fps, int batchSize, int fragmentSize, int ackTimeoutMs) throws Exception {
        try {
            callVoid(
                    new String[]{"SetSEIOptions", "setSEIOptions"},
                    new Class<?>[]{int.class, int.class, int.class, int.class},
                    fps, batchSize, fragmentSize, ackTimeoutMs
            );
            return;
        } catch (NoSuchMethodException first) {
            try {
                callVoid(
                        new String[]{"SetSEIOptions", "setSEIOptions"},
                        new Class<?>[]{long.class, long.class, long.class, long.class},
                        (long) fps, (long) batchSize, (long) fragmentSize, (long) ackTimeoutMs
                );
            } catch (NoSuchMethodException ignored) {
                // Universal-carrier combo AAR should expose this. If not, start may still use upstream defaults.
            }
        }
    }

    private void setVideoOptionsIfAvailable(
            String codec,
            int width,
            int height,
            int fps,
            String bitrate,
            String hw,
            String qrRecovery,
            int qrSize,
            int tileModule,
            int tileRS
    ) throws Exception {
        try {
            callVoid(
                    new String[]{"SetVideoOptions", "setVideoOptions"},
                    new Class<?>[]{String.class, int.class, int.class, int.class, String.class, String.class, String.class, int.class, int.class, int.class},
                    codec, width, height, fps, bitrate, hw, qrRecovery, qrSize, tileModule, tileRS
            );
            return;
        } catch (NoSuchMethodException first) {
            try {
                callVoid(
                        new String[]{"SetVideoOptions", "setVideoOptions"},
                        new Class<?>[]{String.class, long.class, long.class, long.class, String.class, String.class, String.class, long.class, long.class, long.class},
                        codec, (long) width, (long) height, (long) fps, bitrate, hw, qrRecovery, (long) qrSize, (long) tileModule, (long) tileRS
                );
            } catch (NoSuchMethodException ignored) {
                // Universal-carrier combo AAR should expose this. If not, start may still use upstream defaults.
            }
        }
    }

    private void applyCarrierRuntimeOptions(OlcConfig config) throws Exception {
        if (config == null || !"mtslink".equalsIgnoreCase(config.carrier)) return;

        int intervalMs = durationParam(config, 20000, "liveness-interval", "live-interval");
        int timeoutMs = durationParam(config, 15000, "liveness-timeout", "live-timeout");
        int failures = config.intParam("liveness-failures", config.intParam("live-failures", 6));
        setLivenessOptionsIfAvailable(intervalMs, timeoutMs, failures);

        int maxPayload = config.intParam("traffic-max-payload", config.intParam("traffic-max-payload-size", 1200));
        int minDelayMs = durationParam(config, 4, "traffic-min-delay");
        int maxDelayMs = durationParam(config, 18, "traffic-max-delay");
        setTrafficOptionsIfAvailable(maxPayload, minDelayMs, maxDelayMs);
    }

    private int durationParam(OlcConfig config, int defaultMs, String... keys) {
        for (String key : keys) {
            String raw = config.param(key, "");
            if (raw == null || raw.trim().isEmpty()) continue;
            Integer parsed = parseDurationMs(raw.trim());
            if (parsed != null) return parsed;
        }
        return defaultMs;
    }

    private Integer parseDurationMs(String raw) {
        String value = raw.toLowerCase();
        try {
            if (value.endsWith("ms")) {
                return Math.max(0, Integer.parseInt(value.substring(0, value.length() - 2).trim()));
            }
            if (value.endsWith("s")) {
                return Math.max(0, Integer.parseInt(value.substring(0, value.length() - 1).trim()) * 1000);
            }
            return Math.max(0, Integer.parseInt(value));
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private void setLivenessOptionsIfAvailable(int intervalMs, int timeoutMs, int failures) throws Exception {
        try {
            callVoid(
                    new String[]{"SetLivenessOptions", "setLivenessOptions"},
                    new Class<?>[]{int.class, int.class, int.class},
                    intervalMs, timeoutMs, failures
            );
        } catch (NoSuchMethodException first) {
            try {
                callVoid(
                        new String[]{"SetLivenessOptions", "setLivenessOptions"},
                        new Class<?>[]{long.class, long.class, long.class},
                        (long) intervalMs, (long) timeoutMs, (long) failures
                );
            } catch (NoSuchMethodException ignored) {
                // Older AARs fall back to core defaults.
            }
        }
    }

    private void setTrafficOptionsIfAvailable(int maxPayload, int minDelayMs, int maxDelayMs) throws Exception {
        try {
            callVoid(
                    new String[]{"SetTrafficOptions", "setTrafficOptions"},
                    new Class<?>[]{int.class, int.class, int.class},
                    maxPayload, minDelayMs, maxDelayMs
            );
        } catch (NoSuchMethodException first) {
            try {
                callVoid(
                        new String[]{"SetTrafficOptions", "setTrafficOptions"},
                        new Class<?>[]{long.class, long.class, long.class},
                        (long) maxPayload, (long) minDelayMs, (long) maxDelayMs
                );
            } catch (NoSuchMethodException ignored) {
                // Older AARs fall back to core defaults.
            }
        }
    }

    private void startMobileApi(
            String carrier,
            String transport,
            boolean transportApplied,
            String roomId,
            String clientId,
            String keyHex,
            int socksPort,
            String socksUser,
            String socksPass
    ) throws Exception {
        try {
            tryStartWithTransport(carrier, transport, roomId, clientId, keyHex, socksPort, socksUser, socksPass);
            return;
        } catch (NoSuchMethodException noStartWithTransport) {
            if (!OlcUriParser.TRANSPORT_DATA.equals(transport) && !transportApplied) {
                throw new IllegalStateException("combo AAR has no StartWithTransport/SetTransport for " + transport + "; rebuild app/libs/olcrtccombo.aar from l1ch666/mtsRTC mtslink-universal-carrier");
            }
        }

        try {
            tryStart(
                    new Class<?>[]{String.class, String.class, String.class, String.class, int.class, String.class, String.class},
                    carrier, roomId, clientId, keyHex, socksPort, socksUser, socksPass
            );
            return;
        } catch (NoSuchMethodException first) {
            tryStart(
                    new Class<?>[]{String.class, String.class, String.class, String.class, long.class, String.class, String.class},
                    carrier, roomId, clientId, keyHex, (long) socksPort, socksUser, socksPass
            );
        }
    }

    private void tryStart(Class<?>[] types, Object... args) throws Exception {
        callVoid(new String[]{"Start", "start"}, types, args);
    }

    private void tryStartWithTransport(
            String carrier,
            String transport,
            String roomId,
            String clientId,
            String keyHex,
            int socksPort,
            String socksUser,
            String socksPass
    ) throws Exception {
        try {
            callVoid(
                    new String[]{"StartWithTransport", "startWithTransport"},
                    new Class<?>[]{String.class, String.class, String.class, String.class, String.class, int.class, String.class, String.class},
                    carrier, transport, roomId, clientId, keyHex, socksPort, socksUser, socksPass
            );
        } catch (NoSuchMethodException first) {
            callVoid(
                    new String[]{"StartWithTransport", "startWithTransport"},
                    new Class<?>[]{String.class, String.class, String.class, String.class, String.class, long.class, String.class, String.class},
                    carrier, transport, roomId, clientId, keyHex, (long) socksPort, socksUser, socksPass
            );
        }
    }

    public void waitReady(int timeoutMs) throws Exception {
        try {
            callVoid(new String[]{"WaitReady", "waitReady"}, new Class<?>[]{int.class}, timeoutMs);
        } catch (NoSuchMethodException first) {
            callVoid(new String[]{"WaitReady", "waitReady"}, new Class<?>[]{long.class}, (long) timeoutMs);
        }
    }

    public boolean isRunning() {
        try {
            Method method = findMethod(new String[]{"IsRunning", "isRunning"}, new Class<?>[]{});
            Object result = method.invoke(null);
            return result instanceof Boolean && (Boolean) result;
        } catch (Throwable ignored) {
            return true;
        }
    }

    public void stop() {
        try {
            callVoid(new String[]{"Stop", "stop"}, new Class<?>[]{}, new Object[]{});
        } catch (Throwable ignored) {
        }
    }

    private void callVoid(String[] names, Class<?>[] types, Object... args) throws Exception {
        Method method = findMethod(names, types);
        try {
            method.invoke(null, args);
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof Exception) throw (Exception) cause;
            if (cause instanceof Error) throw (Error) cause;
            throw new RuntimeException(cause);
        }
    }

    private Method findMethod(String[] names, Class<?>[] types) throws NoSuchMethodException {
        NoSuchMethodException last = null;
        for (String name : names) {
            try {
                return mobileClass.getMethod(name, types);
            } catch (NoSuchMethodException e) {
                last = e;
            }
        }
        throw last == null ? new NoSuchMethodException() : last;
    }
}
