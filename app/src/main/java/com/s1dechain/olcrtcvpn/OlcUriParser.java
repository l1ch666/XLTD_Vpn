package com.s1dechain.olcrtcvpn;

import java.net.URLDecoder;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

public final class OlcUriParser {
    private OlcUriParser() {}

    public static final String TRANSPORT_DATA = "datachannel";
    public static final String TRANSPORT_VP8 = "vp8channel";
    public static final String TRANSPORT_SEI = "seichannel";
    public static final String TRANSPORT_VIDEO = "videochannel";

    // Kept for older app code/tests that referenced the old names.
    public static final String SUPPORTED_TRANSPORT = TRANSPORT_DATA;
    public static final String SUPPORTED_VP8_TRANSPORT = TRANSPORT_VP8;

    private static final String DEFAULT_CLIENT_ID = "default";

    public static OlcConfig parse(String raw) {
        if (raw == null) throw new IllegalArgumentException("empty link");
        String s = raw.trim();
        if (!s.startsWith("olcrtc://")) {
            throw new IllegalArgumentException("link must start with olcrtc://");
        }

        String body = s.substring("olcrtc://".length());
        int q = body.indexOf('?');
        int at = body.indexOf('@', q + 1);
        int hash = body.indexOf('#', at + 1);

        if (q <= 0) throw new IllegalArgumentException("missing carrier or ?");
        if (at <= q) throw new IllegalArgumentException("missing transport or @");
        if (hash <= at) throw new IllegalArgumentException("missing roomId or #");

        String carrier = decode(body.substring(0, q).trim()).toLowerCase(Locale.ROOT);
        String transportSpec = body.substring(q + 1, at).trim();
        TransportParts parts = parseTransportSpec(transportSpec);
        String transport = normalizeTransport(parts.transport);
        ensureSupportedTransport(transport);

        String roomId = decode(body.substring(at + 1, hash).trim());
        TailParts tail = parseTail(body.substring(hash + 1));
        String keyHex = tail.keyHex.trim();
        String clientId = tail.clientId.trim();
        String comment = tail.comment.trim();

        if (clientId.isEmpty()) {
            clientId = firstNonEmpty(
                    parts.params.get("client-id"),
                    parts.params.get("clientid"),
                    parts.params.get("client"),
                    DEFAULT_CLIENT_ID
            );
        }

        if (carrier.isEmpty()) throw new IllegalArgumentException("carrier is empty");
        if (transport.isEmpty()) throw new IllegalArgumentException("transport is empty");
        if (roomId.isEmpty() && !"jazz".equals(carrier)) throw new IllegalArgumentException("roomId is empty");
        if (clientId.isEmpty()) throw new IllegalArgumentException("clientId is empty");
        if (keyHex.length() != 64) throw new IllegalArgumentException("keyHex must be 64 hex chars");
        if (!keyHex.matches("[0-9a-fA-F]{64}")) throw new IllegalArgumentException("keyHex is not hex");

        return new OlcConfig(carrier, transport, roomId, keyHex, clientId, comment, parts.params);
    }

    private static TailParts parseTail(String rawTail) {
        if (rawTail == null || rawTail.trim().isEmpty()) {
            throw new IllegalArgumentException("missing keyHex");
        }

        int percent = rawTail.indexOf('%');
        int dollar = rawTail.indexOf('$');

        String key;
        String client = "";
        String comment = "";

        if (percent >= 0 && (dollar < 0 || percent < dollar)) {
            key = rawTail.substring(0, percent);
            if (dollar > percent) {
                client = rawTail.substring(percent + 1, dollar);
                comment = rawTail.substring(dollar + 1);
            } else {
                client = rawTail.substring(percent + 1);
            }
        } else if (dollar >= 0) {
            // New universal-carrier URI docs no longer encode client-id. Keep client-id
            // defaulted to "default" and treat $... as UI comment only.
            key = rawTail.substring(0, dollar);
            comment = rawTail.substring(dollar + 1);
        } else {
            key = rawTail;
        }

        return new TailParts(decode(key), decode(client), decode(comment));
    }

    private static TransportParts parseTransportSpec(String spec) {
        if (spec == null || spec.trim().isEmpty()) {
            throw new IllegalArgumentException("transport is empty");
        }
        spec = spec.trim();
        int open = spec.indexOf('<');
        if (open < 0) {
            return new TransportParts(spec, new LinkedHashMap<>());
        }
        int close = spec.lastIndexOf('>');
        if (close < open || close != spec.length() - 1) {
            throw new IllegalArgumentException("bad transport params: expected transport<key=value&...>");
        }
        String transport = spec.substring(0, open).trim();
        String inside = spec.substring(open + 1, close).trim();
        return new TransportParts(transport, parseParams(inside));
    }

    private static Map<String, String> parseParams(String raw) {
        Map<String, String> out = new LinkedHashMap<>();
        if (raw == null || raw.trim().isEmpty()) return out;
        for (String pair : raw.split("&")) {
            if (pair == null || pair.trim().isEmpty()) continue;
            int eq = pair.indexOf('=');
            String key = eq >= 0 ? pair.substring(0, eq) : pair;
            String value = eq >= 0 ? pair.substring(eq + 1) : "";
            key = decode(key).trim().toLowerCase(Locale.ROOT);
            value = decode(value).trim();
            if (!key.isEmpty()) out.put(key, value);
        }
        return out;
    }

    private static String normalizeTransport(String value) {
        String v = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
        if (v.equals("data") || v.equals("dc") || v.equals("data_channel") || v.equals("data-channel")) return TRANSPORT_DATA;
        if (v.equals("vp8") || v.equals("vp8_channel") || v.equals("vp8-channel")) return TRANSPORT_VP8;
        if (v.equals("sei") || v.equals("sei_channel") || v.equals("sei-channel")) return TRANSPORT_SEI;
        if (v.equals("video") || v.equals("vid") || v.equals("video_channel") || v.equals("video-channel")) return TRANSPORT_VIDEO;
        return v;
    }

    public static boolean isSupportedTransport(String transport) {
        return TRANSPORT_DATA.equals(transport)
                || TRANSPORT_VP8.equals(transport)
                || TRANSPORT_SEI.equals(transport)
                || TRANSPORT_VIDEO.equals(transport);
    }

    private static void ensureSupportedTransport(String transport) {
        if (isSupportedTransport(transport)) return;
        throw new IllegalArgumentException("unsupported transport: " + transport + "; use datachannel, vp8channel, seichannel or videochannel");
    }

    private static String firstNonEmpty(String... values) {
        if (values == null) return "";
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) return value.trim();
        }
        return "";
    }

    private static String decode(String value) {
        try {
            return URLDecoder.decode(value, "UTF-8");
        } catch (Exception ignored) {
            return value == null ? "" : value;
        }
    }

    private static final class TailParts {
        final String keyHex;
        final String clientId;
        final String comment;

        TailParts(String keyHex, String clientId, String comment) {
            this.keyHex = keyHex;
            this.clientId = clientId;
            this.comment = comment;
        }
    }

    private static final class TransportParts {
        final String transport;
        final Map<String, String> params;

        TransportParts(String transport, Map<String, String> params) {
            this.transport = transport;
            this.params = params;
        }
    }
}
