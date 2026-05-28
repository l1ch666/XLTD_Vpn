package com.s1dechain.olcrtcvpn;

import android.util.Log;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

public final class Tun2SocksMobileBridge {
    private static final String TAG = "Tun2SocksMobile";
    private final Class<?> mobileClass;

    public Tun2SocksMobileBridge() throws ClassNotFoundException {
        // The combined gomobile AAR exposes Go package "mobile" as Java class mobile.Mobile.
        this.mobileClass = Class.forName("mobile.Mobile");
    }

    public static boolean isAvailable() {
        try {
            Class<?> cls = Class.forName("mobile.Mobile");
            for (Method m : cls.getMethods()) {
                if (m.getName().equals("StartTun2Socks") || m.getName().equals("startTun2Socks")) {
                    return true;
                }
            }
            return false;
        } catch (Throwable ignored) {
            return false;
        }
    }

    public void start(int fd, String proxyUrl, int mtu, String logLevel) throws Exception {
        start(fd, proxyUrl, mtu, logLevel, "1.1.1.1:53", 6);
    }

    public void start(int fd, String proxyUrl, int mtu, String logLevel, String dnsUpstream) throws Exception {
        start(fd, proxyUrl, mtu, logLevel, dnsUpstream, 6);
    }

    public void start(int fd, String proxyUrl, int mtu, String logLevel, String dnsUpstream, int tcpDialLimit) throws Exception {
        int limit = Math.max(1, Math.min(32, tcpDialLimit));
        Log.i(TAG, "starting in-process tun2socks: fd=" + fd + " proxy=" + proxyUrl + " mtu=" + mtu + " dns=" + dnsUpstream + " tcpLimit=" + limit);

        try {
            callVoid(
                    new String[]{"StartTun2SocksWithDNSAndLimit", "startTun2SocksWithDNSAndLimit"},
                    new Class<?>[]{int.class, String.class, int.class, String.class, String.class, int.class},
                    fd, proxyUrl, mtu, logLevel, dnsUpstream, limit
            );
            return;
        } catch (NoSuchMethodException first) {
            try {
                callVoid(
                        new String[]{"StartTun2SocksWithDNSAndLimit", "startTun2SocksWithDNSAndLimit"},
                        new Class<?>[]{long.class, String.class, long.class, String.class, String.class, long.class},
                        (long) fd, proxyUrl, (long) mtu, logLevel, dnsUpstream, (long) limit
                );
                return;
            } catch (NoSuchMethodException second) {
                // Backward compatibility with older combo AAR without the TCP limiter.
                try {
                    callVoid(
                            new String[]{"StartTun2SocksWithDNS", "startTun2SocksWithDNS"},
                            new Class<?>[]{int.class, String.class, int.class, String.class, String.class},
                            fd, proxyUrl, mtu, logLevel, dnsUpstream
                    );
                    return;
                } catch (NoSuchMethodException third) {
                    try {
                        callVoid(
                                new String[]{"StartTun2SocksWithDNS", "startTun2SocksWithDNS"},
                                new Class<?>[]{long.class, String.class, long.class, String.class, String.class},
                                (long) fd, proxyUrl, (long) mtu, logLevel, dnsUpstream
                        );
                        return;
                    } catch (NoSuchMethodException fourth) {
                        // Backward compatibility with older combo AAR without DNS hijack.
                        try {
                            callVoid(
                                    new String[]{"StartTun2Socks", "startTun2Socks"},
                                    new Class<?>[]{int.class, String.class, int.class, String.class},
                                    fd, proxyUrl, mtu, logLevel
                            );
                            return;
                        } catch (NoSuchMethodException fifth) {
                            callVoid(
                                    new String[]{"StartTun2Socks", "startTun2Socks"},
                                    new Class<?>[]{long.class, String.class, long.class, String.class},
                                    (long) fd, proxyUrl, (long) mtu, logLevel
                            );
                        }
                    }
                }
            }
        }
    }

    public void stop() {
        try {
            callVoid(new String[]{"StopTun2Socks", "stopTun2Socks"}, new Class<?>[]{}, new Object[]{});
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
