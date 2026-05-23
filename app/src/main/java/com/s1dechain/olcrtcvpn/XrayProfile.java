package com.s1dechain.olcrtcvpn;

import android.util.Base64;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

public final class XrayProfile {
    public final String displayName;
    public final String protocol;
    public final String configJson;

    private XrayProfile(String displayName, String protocol, String configJson) {
        this.displayName = displayName;
        this.protocol = protocol;
        this.configJson = configJson;
    }

    public static boolean isXray(String raw) {
        String v = extract(raw).trim().toLowerCase(Locale.ROOT);
        return v.startsWith("{")
                || v.startsWith("xray://")
                || v.startsWith("vless://")
                || v.startsWith("vmess://")
                || v.startsWith("trojan://")
                || v.startsWith("ss://")
                || v.startsWith("socks://")
                || v.startsWith("http-proxy://");
    }

    public static XrayProfile parse(String raw, int socksPort) throws Exception {
        String value = extract(raw).trim();
        if (value.isEmpty()) throw new IllegalArgumentException("empty Xray profile");
        String lower = value.toLowerCase(Locale.ROOT);
        if (value.startsWith("{")) {
            return new XrayProfile("Xray JSON", "json", ensureLocalSocksInbound(value, socksPort));
        }
        if (lower.startsWith("xray://")) {
            String json = decodePayload(value.substring("xray://".length()));
            if (!json.trim().startsWith("{")) {
                throw new IllegalArgumentException("xray:// payload must be URL-encoded or base64url JSON");
            }
            return new XrayProfile("Xray JSON", "json", ensureLocalSocksInbound(json, socksPort));
        }
        if (lower.startsWith("vmess://")) return parseVmess(value, socksPort);
        if (lower.startsWith("vless://")) return parseUriOutbound(value, "vless", socksPort);
        if (lower.startsWith("trojan://")) return parseUriOutbound(value, "trojan", socksPort);
        if (lower.startsWith("ss://")) return parseShadowsocks(value, socksPort);
        if (lower.startsWith("socks://")) return parseUriOutbound(value, "socks", socksPort);
        if (lower.startsWith("http-proxy://")) return parseHttpProxy(value, socksPort);
        throw new IllegalArgumentException("unsupported Xray profile format");
    }

    private static XrayProfile parseUriOutbound(String raw, String protocol, int socksPort) throws Exception {
        URI uri = new URI(raw);
        Map<String, String> query = parseQuery(uri.getRawQuery());
        String host = firstNonEmpty(uri.getHost(), "");
        int port = uri.getPort() > 0 ? uri.getPort() : defaultPort(query);
        String name = firstNonEmpty(decode(uri.getRawFragment()), host, protocol);
        String userInfo = decode(uri.getRawUserInfo());

        String outbound;
        if ("vless".equals(protocol)) {
            outbound = "{"
                    + q("protocol") + ":" + q("vless") + ","
                    + q("tag") + ":" + q("proxy") + ","
                    + q("settings") + ":{"
                    + q("vnext") + ":[{"
                    + q("address") + ":" + q(host) + ","
                    + q("port") + ":" + port + ","
                    + q("users") + ":[{"
                    + q("id") + ":" + q(userInfo) + ","
                    + q("encryption") + ":" + q(firstNonEmpty(query.get("encryption"), "none"))
                    + optionalString("flow", query.get("flow"))
                    + "}]}]}}";
        } else if ("trojan".equals(protocol)) {
            outbound = "{"
                    + q("protocol") + ":" + q("trojan") + ","
                    + q("tag") + ":" + q("proxy") + ","
                    + q("settings") + ":{"
                    + q("servers") + ":[{"
                    + q("address") + ":" + q(host) + ","
                    + q("port") + ":" + port + ","
                    + q("password") + ":" + q(userInfo)
                    + "}]}}";
        } else {
            outbound = socksOutbound(userInfo, host, port);
        }

        outbound = addStreamSettings(outbound, query);
        return new XrayProfile(name, protocol, buildConfig(outbound, socksPort));
    }

    private static XrayProfile parseHttpProxy(String raw, int socksPort) throws Exception {
        URI uri = new URI("http://" + raw.substring("http-proxy://".length()));
        String host = firstNonEmpty(uri.getHost(), "");
        int port = uri.getPort() > 0 ? uri.getPort() : 8080;
        String userInfo = decode(uri.getRawUserInfo());
        String users = "";
        if (!userInfo.isEmpty()) {
            String[] parts = userInfo.split(":", 2);
            users = "," + q("users") + ":[{" + q("user") + ":" + q(parts[0]) + "," + q("pass") + ":" + q(parts.length > 1 ? parts[1] : "") + "}]";
        }
        String outbound = "{"
                + q("protocol") + ":" + q("http") + ","
                + q("tag") + ":" + q("proxy") + ","
                + q("settings") + ":{"
                + q("servers") + ":[{"
                + q("address") + ":" + q(host) + ","
                + q("port") + ":" + port
                + users
                + "}]}}";
        return new XrayProfile(firstNonEmpty(decode(uri.getRawFragment()), host, "http"), "http", buildConfig(outbound, socksPort));
    }

    private static XrayProfile parseVmess(String raw, int socksPort) {
        String json = decodeBase64Loose(raw.substring("vmess://".length()));
        Map<String, String> fields = parseFlatJson(json);
        String host = fields.getOrDefault("add", "");
        int port = parseInt(fields.get("port"), 443);
        String name = firstNonEmpty(fields.get("ps"), host, "vmess");
        String outbound = "{"
                + q("protocol") + ":" + q("vmess") + ","
                + q("tag") + ":" + q("proxy") + ","
                + q("settings") + ":{"
                + q("vnext") + ":[{"
                + q("address") + ":" + q(host) + ","
                + q("port") + ":" + port + ","
                + q("users") + ":[{"
                + q("id") + ":" + q(fields.getOrDefault("id", "")) + ","
                + q("alterId") + ":" + parseInt(fields.get("aid"), 0) + ","
                + q("security") + ":" + q(firstNonEmpty(fields.get("scy"), "auto"))
                + "}]}]}}";
        Map<String, String> query = new LinkedHashMap<>();
        query.put("type", firstNonEmpty(fields.get("net"), "tcp"));
        query.put("security", firstNonEmpty(fields.get("tls"), "none"));
        query.put("sni", fields.getOrDefault("sni", ""));
        query.put("host", fields.getOrDefault("host", ""));
        query.put("path", fields.getOrDefault("path", ""));
        query.put("alpn", fields.getOrDefault("alpn", ""));
        query.put("fp", fields.getOrDefault("fp", ""));
        outbound = addStreamSettings(outbound, query);
        return new XrayProfile(name, "vmess", buildConfig(outbound, socksPort));
    }

    private static XrayProfile parseShadowsocks(String raw, int socksPort) {
        String body = raw.substring("ss://".length());
        String name = "";
        int hash = body.indexOf('#');
        if (hash >= 0) {
            name = decode(body.substring(hash + 1));
            body = body.substring(0, hash);
        }
        int query = body.indexOf('?');
        if (query >= 0) body = body.substring(0, query);

        String userInfo;
        String server;
        int at = body.lastIndexOf('@');
        if (at >= 0) {
            userInfo = body.substring(0, at);
            server = body.substring(at + 1);
            userInfo = userInfo.contains(":") ? decode(userInfo) : decodeBase64Loose(userInfo);
        } else {
            String decoded = decodeBase64Loose(body);
            at = decoded.lastIndexOf('@');
            if (at < 0) throw new IllegalArgumentException("bad ss link");
            userInfo = decoded.substring(0, at);
            server = decoded.substring(at + 1);
        }

        String[] auth = userInfo.split(":", 2);
        if (auth.length != 2) throw new IllegalArgumentException("bad ss credentials");
        HostPort hp = splitHostPort(server);
        String outbound = "{"
                + q("protocol") + ":" + q("shadowsocks") + ","
                + q("tag") + ":" + q("proxy") + ","
                + q("settings") + ":{"
                + q("servers") + ":[{"
                + q("address") + ":" + q(hp.host) + ","
                + q("port") + ":" + hp.port + ","
                + q("method") + ":" + q(auth[0]) + ","
                + q("password") + ":" + q(auth[1])
                + "}]}}";
        return new XrayProfile(firstNonEmpty(name, hp.host, "shadowsocks"), "shadowsocks", buildConfig(outbound, socksPort));
    }

    private static String addStreamSettings(String outbound, Map<String, String> query) {
        String network = firstNonEmpty(query.get("type"), query.get("network"), "tcp").toLowerCase(Locale.ROOT);
        String security = firstNonEmpty(query.get("security"), "none").toLowerCase(Locale.ROOT);
        StringBuilder stream = new StringBuilder();
        stream.append("{").append(q("network")).append(":").append(q(network));
        if (!security.isEmpty() && !"none".equals(security)) {
            stream.append(",").append(q("security")).append(":").append(q(security));
            if ("tls".equals(security)) {
                stream.append(",").append(q("tlsSettings")).append(":{")
                        .append(q("serverName")).append(":").append(q(firstNonEmpty(query.get("sni"), query.get("serverName"))))
                        .append(",").append(q("allowInsecure")).append(":").append(parseBool(query.get("allowInsecure")))
                        .append("}");
            } else if ("reality".equals(security)) {
                stream.append(",").append(q("realitySettings")).append(":{")
                        .append(q("serverName")).append(":").append(q(firstNonEmpty(query.get("sni"), query.get("serverName"))))
                        .append(optionalJsonString("fingerprint", query.get("fp")))
                        .append(optionalJsonString("publicKey", query.get("pbk")))
                        .append(optionalJsonString("shortId", query.get("sid")))
                        .append(optionalJsonString("spiderX", query.get("spx")))
                        .append("}");
            }
        }
        if ("ws".equals(network)) {
            stream.append(",").append(q("wsSettings")).append(":{")
                    .append(q("path")).append(":").append(q(firstNonEmpty(query.get("path"), "/")))
                    .append(",").append(q("headers")).append(":{").append(q("Host")).append(":").append(q(firstNonEmpty(query.get("host"), ""))).append("}}");
        } else if ("grpc".equals(network)) {
            stream.append(",").append(q("grpcSettings")).append(":{").append(q("serviceName")).append(":").append(q(firstNonEmpty(query.get("serviceName"), ""))).append("}");
        } else if ("http".equals(network) || "h2".equals(network)) {
            stream = new StringBuilder("{").append(q("network")).append(":").append(q("http"));
            if (!security.isEmpty() && !"none".equals(security)) {
                stream.append(",").append(q("security")).append(":").append(q(security));
                if ("tls".equals(security)) {
                    stream.append(",").append(q("tlsSettings")).append(":{")
                            .append(q("serverName")).append(":").append(q(firstNonEmpty(query.get("sni"), query.get("serverName"))))
                            .append(",").append(q("allowInsecure")).append(":").append(parseBool(query.get("allowInsecure")))
                            .append("}");
                } else if ("reality".equals(security)) {
                    stream.append(",").append(q("realitySettings")).append(":{")
                            .append(q("serverName")).append(":").append(q(firstNonEmpty(query.get("sni"), query.get("serverName"))))
                            .append(optionalJsonString("fingerprint", query.get("fp")))
                            .append(optionalJsonString("publicKey", query.get("pbk")))
                            .append(optionalJsonString("shortId", query.get("sid")))
                            .append(optionalJsonString("spiderX", query.get("spx")))
                            .append("}");
                }
            }
            stream.append(",").append(q("httpSettings")).append(":{")
                    .append(q("path")).append(":").append(q(firstNonEmpty(query.get("path"), "/")))
                    .append(",").append(q("host")).append(":").append(jsonStringArray(query.get("host")))
                    .append("}");
        } else if ("xhttp".equals(network) || "splithttp".equals(network)) {
            stream.append(",").append(q(network + "Settings")).append(":{")
                    .append(q("path")).append(":").append(q(firstNonEmpty(query.get("path"), "/")))
                    .append(optionalJsonString("host", query.get("host")))
                    .append(optionalJsonString("mode", query.get("mode")))
                    .append("}");
        } else if ("kcp".equals(network)) {
            stream.append(",").append(q("kcpSettings")).append(":{")
                    .append(q("header")).append(":{").append(q("type")).append(":").append(q(firstNonEmpty(query.get("headerType"), query.get("header"), "none"))).append("}}");
        } else if ("quic".equals(network)) {
            stream.append(",").append(q("quicSettings")).append(":{")
                    .append(q("security")).append(":").append(q(firstNonEmpty(query.get("quicSecurity"), "")))
                    .append(",").append(q("key")).append(":").append(q(firstNonEmpty(query.get("key"), "")))
                    .append(",").append(q("header")).append(":{").append(q("type")).append(":").append(q(firstNonEmpty(query.get("headerType"), query.get("header"), "none"))).append("}}");
        }
        stream.append("}");
        return outbound.substring(0, outbound.length() - 1) + "," + q("streamSettings") + ":" + stream + "}";
    }

    private static String buildConfig(String outbound, int socksPort) {
        return "{"
                + q("log") + ":{" + q("loglevel") + ":" + q("warning") + "},"
                + q("inbounds") + ":[{"
                + q("tag") + ":" + q("xltd-socks-in") + ","
                + q("listen") + ":" + q("127.0.0.1") + ","
                + q("port") + ":" + socksPort + ","
                + q("protocol") + ":" + q("socks") + ","
                + q("settings") + ":{" + q("auth") + ":" + q("noauth") + "," + q("udp") + ":true},"
                + q("sniffing") + ":{" + q("enabled") + ":true," + q("destOverride") + ":[\"http\",\"tls\",\"quic\"]}"
                + "}],"
                + q("outbounds") + ":[" + outbound + ",{\"tag\":\"direct\",\"protocol\":\"freedom\"},{\"tag\":\"block\",\"protocol\":\"blackhole\"}],"
                + q("routing") + ":{" + q("domainStrategy") + ":" + q("IPIfNonMatch") + "," + q("rules") + ":[]}"
                + "}";
    }

    private static String ensureLocalSocksInbound(String json, int socksPort) throws Exception {
        org.json.JSONObject root = new org.json.JSONObject(json);
        org.json.JSONArray existing = root.optJSONArray("inbounds");
        org.json.JSONArray inbounds = new org.json.JSONArray();
        inbounds.put(buildLocalSocksInbound(socksPort));
        if (existing != null) {
            for (int i = 0; i < existing.length(); i++) {
                org.json.JSONObject inbound = existing.optJSONObject(i);
                if (inbound != null && "xltd-socks-in".equals(inbound.optString("tag"))) {
                    continue;
                }
                inbounds.put(existing.get(i));
            }
        }
        root.put("inbounds", inbounds);
        if (!root.has("log")) {
            root.put("log", new org.json.JSONObject().put("loglevel", "warning"));
        }
        return root.toString(2);
    }

    private static org.json.JSONObject buildLocalSocksInbound(int socksPort) throws Exception {
        return new org.json.JSONObject()
                .put("tag", "xltd-socks-in")
                .put("listen", "127.0.0.1")
                .put("port", socksPort)
                .put("protocol", "socks")
                .put("settings", new org.json.JSONObject()
                        .put("auth", "noauth")
                        .put("udp", true))
                .put("sniffing", new org.json.JSONObject()
                        .put("enabled", true)
                        .put("destOverride", new org.json.JSONArray()
                                .put("http")
                                .put("tls")
                                .put("quic")));
    }

    private static String socksOutbound(String userInfo, String host, int port) {
        String users = "";
        if (userInfo != null && !userInfo.isEmpty()) {
            String[] parts = userInfo.split(":", 2);
            users = "," + q("users") + ":[{" + q("user") + ":" + q(parts[0]) + "," + q("pass") + ":" + q(parts.length > 1 ? parts[1] : "") + "}]";
        }
        return "{"
                + q("protocol") + ":" + q("socks") + ","
                + q("tag") + ":" + q("proxy") + ","
                + q("settings") + ":{" + q("servers") + ":[{"
                + q("address") + ":" + q(host) + ","
                + q("port") + ":" + port
                + users
                + "}]}}";
    }

    private static Map<String, String> parseQuery(String raw) {
        Map<String, String> out = new LinkedHashMap<>();
        if (raw == null || raw.trim().isEmpty()) return out;
        for (String pair : raw.split("&")) {
            if (pair.isEmpty()) continue;
            int eq = pair.indexOf('=');
            String key = eq >= 0 ? pair.substring(0, eq) : pair;
            String val = eq >= 0 ? pair.substring(eq + 1) : "";
            out.put(decode(key), decode(val));
        }
        return out;
    }

    private static Map<String, String> parseFlatJson(String json) {
        Map<String, String> out = new LinkedHashMap<>();
        int i = 0;
        while (i < json.length()) {
            int keyStart = json.indexOf('"', i);
            if (keyStart < 0) break;
            int keyEnd = json.indexOf('"', keyStart + 1);
            if (keyEnd < 0) break;
            int colon = json.indexOf(':', keyEnd + 1);
            if (colon < 0) break;
            String key = unescapeJson(json.substring(keyStart + 1, keyEnd));
            int v = colon + 1;
            while (v < json.length() && Character.isWhitespace(json.charAt(v))) v++;
            String value;
            if (v < json.length() && json.charAt(v) == '"') {
                int end = v + 1;
                boolean escaped = false;
                while (end < json.length()) {
                    char c = json.charAt(end);
                    if (c == '"' && !escaped) break;
                    escaped = c == '\\' && !escaped;
                    if (c != '\\') escaped = false;
                    end++;
                }
                value = unescapeJson(json.substring(v + 1, Math.min(end, json.length())));
                i = end + 1;
            } else {
                int end = v;
                while (end < json.length() && ",}".indexOf(json.charAt(end)) < 0) end++;
                value = json.substring(v, end).trim();
                i = end + 1;
            }
            out.put(key, value);
        }
        return out;
    }

    private static String extract(String raw) {
        String value = raw == null ? "" : stripPrefix(raw.trim());
        String lower = value.toLowerCase(Locale.ROOT);
        String[] schemes = new String[]{"xray://", "vless://", "vmess://", "trojan://", "ss://", "socks://", "http-proxy://", "{"};
        int start = -1;
        for (String scheme : schemes) {
            int idx = lower.indexOf(scheme);
            if (idx >= 0 && (start < 0 || idx < start)) start = idx;
        }
        if (start > 0) value = value.substring(start).trim();
        int cr = value.indexOf('\r');
        int lf = value.indexOf('\n');
        int end = -1;
        if (cr >= 0 && lf >= 0) end = Math.min(cr, lf);
        else if (cr >= 0) end = cr;
        else if (lf >= 0) end = lf;
        return end >= 0 ? value.substring(0, end).trim() : value;
    }

    private static String stripPrefix(String value) {
        int start = 0;
        while (start < value.length()) {
            char c = value.charAt(start);
            if (c != '\uFEFF' && c != '\u200B' && c != '\u0000' && !Character.isWhitespace(c)) {
                break;
            }
            start++;
        }
        return start == 0 ? value : value.substring(start);
    }

    private static String decodePayload(String payload) {
        String decoded = decode(payload.trim());
        if (decoded.trim().startsWith("{")) return decoded;
        return decodeBase64Loose(payload);
    }

    private static String decodeBase64Loose(String value) {
        String v = value.trim().split("[?#]", 2)[0].replace('-', '+').replace('_', '/');
        int mod = v.length() % 4;
        if (mod > 0) v = v + "====".substring(mod);
        return new String(Base64.decode(v, Base64.DEFAULT), StandardCharsets.UTF_8);
    }

    private static String decode(String value) {
        if (value == null) return "";
        try {
            return URLDecoder.decode(value, "UTF-8");
        } catch (Exception ignored) {
            return value;
        }
    }

    private static int defaultPort(Map<String, String> query) {
        String security = firstNonEmpty(query.get("security"), "none");
        return "tls".equals(security) || "reality".equals(security) ? 443 : 80;
    }

    private static boolean parseBool(String value) {
        if (value == null) return false;
        String v = value.trim().toLowerCase(Locale.ROOT);
        return "1".equals(v) || "true".equals(v) || "yes".equals(v);
    }

    private static int parseInt(String raw, int fallback) {
        try {
            return Integer.parseInt(raw == null ? "" : raw.trim());
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private static String optionalString(String key, String value) {
        return value == null || value.trim().isEmpty() ? "" : "," + q(key) + ":" + q(value.trim());
    }

    private static String optionalJsonString(String key, String value) {
        return value == null || value.trim().isEmpty() ? "" : "," + q(key) + ":" + q(value.trim());
    }

    private static String jsonStringArray(String value) {
        if (value == null || value.trim().isEmpty()) return "[]";
        String[] parts = value.split(",");
        StringBuilder sb = new StringBuilder("[");
        for (String part : parts) {
            String trimmed = part.trim();
            if (trimmed.isEmpty()) continue;
            if (sb.length() > 1) sb.append(",");
            sb.append(q(trimmed));
        }
        return sb.append("]").toString();
    }

    private static String firstNonEmpty(String... values) {
        if (values == null) return "";
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) return value.trim();
        }
        return "";
    }

    private static String q(String value) {
        if (value == null) value = "";
        return "\"" + value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                + "\"";
    }

    private static String unescapeJson(String value) {
        return value.replace("\\\"", "\"").replace("\\\\", "\\");
    }

    private static HostPort splitHostPort(String value) {
        value = decode(value);
        int colon = value.lastIndexOf(':');
        if (colon <= 0 || colon + 1 >= value.length()) throw new IllegalArgumentException("missing host:port");
        return new HostPort(value.substring(0, colon), parseInt(value.substring(colon + 1), 0));
    }

    private static final class HostPort {
        final String host;
        final int port;

        HostPort(String host, int port) {
            this.host = host;
            this.port = port;
        }
    }
}
