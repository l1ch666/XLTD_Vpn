package com.s1dechain.olcrtcvpn;

import android.content.Context;
import android.content.res.AssetManager;
import android.os.Build;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

final class AndroidVideoRuntime {
    private static final String ASSET_ROOT = "ffmpeg";
    private static final String VERSION_MARKER = "ffmpegbin-8.1-v1";

    private AndroidVideoRuntime() {
    }

    static String prepare(Context context, OlcConfig config) throws IOException {
        if (config == null || !OlcUriParser.TRANSPORT_VIDEO.equals(config.transport)) {
            return "";
        }

        String explicit = firstNonEmpty(
                config.param("android-ffmpeg", ""),
                config.param("ffmpeg-path", ""),
                config.param("ffmpeg", "")
        );
        if (!explicit.isEmpty()) {
            File file = new File(explicit);
            if (!file.isFile()) {
                throw new IOException("Android ffmpeg binary was not found: " + explicit);
            }
            ensureExecutable(file);
            return file.getAbsolutePath();
        }

        AssetManager assets = context.getAssets();
        for (String abi : Build.SUPPORTED_ABIS) {
            String assetPath = ASSET_ROOT + "/" + abi + "/ffmpeg";
            if (!assetExists(assets, assetPath)) {
                continue;
            }
            File out = new File(new File(context.getNoBackupFilesDir(), "olcrtc-video/" + abi), "ffmpeg");
            extractIfNeeded(assets, assetPath, out);
            ensureExecutable(out);
            return out.getAbsolutePath();
        }

        throw new IOException("videochannel requires bundled Android ffmpeg. Run scripts/build_combo_aar.sh so assets/ffmpeg/<abi>/ffmpeg is packaged, or pass android-ffmpeg=<path> in the link.");
    }

    private static String firstNonEmpty(String... values) {
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
        }
        return "";
    }

    private static boolean assetExists(AssetManager assets, String path) {
        try (InputStream ignored = assets.open(path)) {
            return true;
        } catch (IOException ignored) {
            return false;
        }
    }

    private static void extractIfNeeded(AssetManager assets, String assetPath, File out) throws IOException {
        File parent = out.getParentFile();
        if (parent == null) {
            throw new IOException("invalid ffmpeg output path: " + out);
        }

        File marker = new File(parent, ".version");
        String desiredMarker = VERSION_MARKER + ":" + assetPath;
        if (out.isFile() && out.length() > 0 && marker.isFile()) {
            if (desiredMarker.equals(readText(marker))) {
                return;
            }
        }

        if (!parent.isDirectory() && !parent.mkdirs()) {
            throw new IOException("failed to create ffmpeg runtime dir: " + parent);
        }

        File tmp = new File(out.getAbsolutePath() + ".tmp");
        try (InputStream in = assets.open(assetPath);
             FileOutputStream outStream = new FileOutputStream(tmp)) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = in.read(buffer)) >= 0) {
                outStream.write(buffer, 0, read);
            }
        }
        if (out.exists() && !out.delete()) {
            throw new IOException("failed to replace ffmpeg binary: " + out);
        }
        if (!tmp.renameTo(out)) {
            throw new IOException("failed to install ffmpeg binary: " + out);
        }
        writeText(marker, desiredMarker);
    }

    private static String readText(File file) throws IOException {
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] data = new byte[(int) file.length()];
            int offset = 0;
            while (offset < data.length) {
                int read = in.read(data, offset, data.length - offset);
                if (read < 0) break;
                offset += read;
            }
            return new String(data, 0, offset, StandardCharsets.UTF_8);
        }
    }

    private static void writeText(File file, String text) throws IOException {
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(text.getBytes(StandardCharsets.UTF_8));
        }
    }

    private static void ensureExecutable(File file) throws IOException {
        if (file.canExecute()) {
            return;
        }
        if (!file.setExecutable(true, true)) {
            try {
                Process process = new ProcessBuilder("chmod", "700", file.getAbsolutePath()).start();
                if (process.waitFor() != 0) {
                    throw new IOException("chmod failed for " + file);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IOException("interrupted while chmod ffmpeg", e);
            }
        }
        if (!file.canExecute()) {
            throw new IOException("ffmpeg binary is not executable: " + file);
        }
    }
}
