package com.s1dechain.olcrtcvpn;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public final class XrayRuntime {
    private static final String TAG = "XrayRuntime";

    private final Process process;
    private final Thread logThread;

    private XrayRuntime(Process process, Thread logThread) {
        this.process = process;
        this.logThread = logThread;
    }

    public static XrayRuntime start(Context context, XrayProfile profile, int socksPort) throws Exception {
        File binary = prepareBinary(context);
        File assetDir = prepareAssets(context);
        File configDir = new File(context.getFilesDir(), "xray");
        if (!configDir.exists() && !configDir.mkdirs()) {
            throw new IllegalStateException("cannot create Xray config dir");
        }
        File config = new File(configDir, "config-" + socksPort + ".json");
        try (FileOutputStream out = new FileOutputStream(config, false)) {
            out.write(profile.configJson.getBytes(StandardCharsets.UTF_8));
        }

        ProcessBuilder builder = new ProcessBuilder(
                binary.getAbsolutePath(),
                "run",
                "-config",
                config.getAbsolutePath(),
                "-format",
                "json"
        );
        builder.redirectErrorStream(true);
        builder.environment().put("XRAY_LOCATION_ASSET", assetDir.getAbsolutePath());
        builder.directory(configDir);
        Process process = builder.start();
        Thread logThread = new Thread(() -> readLogs(process), "xray-log-reader");
        logThread.setDaemon(true);
        logThread.start();
        Log.i(TAG, "xray started pid=" + pidOf(process) + " protocol=" + profile.protocol);
        return new XrayRuntime(process, logThread);
    }

    public boolean isRunning() {
        try {
            process.exitValue();
            return false;
        } catch (IllegalThreadStateException running) {
            return true;
        }
    }

    public void stop() {
        try {
            process.destroy();
            try {
                process.waitFor();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        } catch (Throwable ignored) {
        }
        if (isRunning()) {
            try { process.destroyForcibly(); } catch (Throwable ignored) {}
        }
    }

    private static File prepareBinary(Context context) throws Exception {
        String abi = chooseAbi(context);
        File dir = new File(context.getCodeCacheDir(), "xray-runtime/" + abi);
        if (!dir.exists() && !dir.mkdirs()) {
            throw new IllegalStateException("cannot create Xray runtime dir");
        }
        File binary = new File(dir, "xray");
        copyAsset(context, "xray/" + abi + "/xray", binary);
        chmod(binary);
        return binary;
    }

    private static File prepareAssets(Context context) throws Exception {
        String abi = chooseAbi(context);
        File dir = new File(context.getFilesDir(), "xray/assets");
        if (!dir.exists() && !dir.mkdirs()) {
            throw new IllegalStateException("cannot create Xray asset dir");
        }
        copyAssetIfExists(context, "xray/" + abi + "/geoip.dat", new File(dir, "geoip.dat"));
        copyAssetIfExists(context, "xray/" + abi + "/geosite.dat", new File(dir, "geosite.dat"));
        return dir;
    }

    private static String chooseAbi(Context context) throws Exception {
        String[] supported = Build.SUPPORTED_ABIS == null ? new String[0] : Build.SUPPORTED_ABIS;
        for (String abi : supported) {
            if (assetExists(context, "xray/" + abi + "/xray")) return abi;
        }
        throw new IllegalStateException("No bundled Xray binary for device ABI. Build with ANDROID_XRAY_ABIS including one of: " + String.join(",", supported));
    }

    private static void copyAssetIfExists(Context context, String asset, File target) throws Exception {
        if (!assetExists(context, asset)) return;
        copyAsset(context, asset, target);
    }

    private static boolean assetExists(Context context, String asset) {
        try (InputStream in = context.getAssets().open(asset)) {
            return in != null;
        } catch (Exception ignored) {
            return false;
        }
    }

    private static void copyAsset(Context context, String asset, File target) throws Exception {
        if (target.exists() && target.length() > 0) return;
        File parent = target.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("cannot create " + parent);
        }
        File tmp = new File(target.getAbsolutePath() + ".tmp");
        try (InputStream in = context.getAssets().open(asset);
             FileOutputStream out = new FileOutputStream(tmp, false)) {
            byte[] buf = new byte[64 * 1024];
            int n;
            while ((n = in.read(buf)) >= 0) {
                out.write(buf, 0, n);
            }
        }
        if (target.exists() && !target.delete()) {
            throw new IllegalStateException("cannot replace " + target);
        }
        if (!tmp.renameTo(target)) {
            throw new IllegalStateException("cannot move " + tmp + " to " + target);
        }
    }

    private static void chmod(File file) {
        file.setReadable(true, true);
        file.setWritable(true, true);
        file.setExecutable(true, true);
        try {
            Process process = new ProcessBuilder("chmod", "700", file.getAbsolutePath()).start();
            process.waitFor();
        } catch (Throwable ignored) {
        }
    }

    private static void readLogs(Process process) {
        try (InputStream in = process.getInputStream()) {
            byte[] buf = new byte[4096];
            StringBuilder line = new StringBuilder();
            int n;
            while ((n = in.read(buf)) >= 0) {
                for (int i = 0; i < n; i++) {
                    char c = (char) (buf[i] & 0xff);
                    if (c == '\n') {
                        String text = line.toString().trim();
                        if (!text.isEmpty()) Log.i("XrayCore", text);
                        line.setLength(0);
                    } else if (c != '\r') {
                        line.append(c);
                    }
                }
            }
        } catch (Throwable t) {
            Log.w(TAG, "xray log reader failed", t);
        }
    }

    private static long pidOf(Process process) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                Object value = process.getClass().getMethod("pid").invoke(process);
                return value instanceof Number ? ((Number) value).longValue() : -1;
            } catch (Throwable ignored) {}
        }
        return -1;
    }
}
