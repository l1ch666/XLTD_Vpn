package com.s1dechain.olcrtcvpn;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public final class OlcConfig {
    public final String carrier;
    public final String transport;
    public final String roomId;
    public final String keyHex;
    public final String clientId;
    public final String comment;
    public final Map<String, String> params;

    public OlcConfig(String carrier, String transport, String roomId, String keyHex, String clientId, String comment) {
        this(carrier, transport, roomId, keyHex, clientId, comment, Collections.emptyMap());
    }

    public OlcConfig(String carrier, String transport, String roomId, String keyHex, String clientId, String comment, Map<String, String> params) {
        this.carrier = carrier;
        this.transport = transport;
        this.roomId = roomId;
        this.keyHex = keyHex;
        this.clientId = clientId;
        this.comment = comment == null ? "" : comment;
        Map<String, String> safeParams = params == null ? Collections.<String, String>emptyMap() : params;
        this.params = Collections.unmodifiableMap(new LinkedHashMap<>(safeParams));
    }

    public String param(String key, String fallback) {
        if (key == null) return fallback;
        String value = params.get(key);
        if (value == null) value = params.get(key.toLowerCase());
        if (value == null || value.trim().isEmpty()) return fallback;
        return value.trim();
    }

    public int intParam(String key, int fallback) {
        String value = param(key, null);
        if (value == null) return fallback;
        try {
            return Integer.parseInt(value.trim());
        } catch (Exception ignored) {
            return fallback;
        }
    }

    public boolean hasParam(String key) {
        if (key == null) return false;
        return params.containsKey(key) || params.containsKey(key.toLowerCase());
    }

    public boolean hasAnyParam(String... keys) {
        if (keys == null) return false;
        for (String key : keys) {
            if (hasParam(key)) return true;
        }
        return false;
    }

    public boolean hasParams() {
        return !params.isEmpty();
    }

    public String paramsPretty() {
        if (params.isEmpty()) return "";
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> e : params.entrySet()) {
            if (sb.length() > 0) sb.append(", ");
            sb.append(e.getKey()).append("=").append(e.getValue());
        }
        return sb.toString();
    }

    public String pretty() {
        return "carrier=" + carrier + "\n" +
                "transport=" + transport + "\n" +
                "roomId=" + roomId + "\n" +
                "clientId=" + clientId +
                (params.isEmpty() ? "" : "\nparams=" + paramsPretty()) +
                (comment.isEmpty() ? "" : "\ncomment=" + comment);
    }
}
