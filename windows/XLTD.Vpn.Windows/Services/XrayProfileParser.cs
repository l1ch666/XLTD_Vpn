using System.Buffers.Text;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using XLTD.Vpn.Windows.Models;

namespace XLTD.Vpn.Windows.Services;

internal static class XrayProfileParser
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static bool IsXray(string? raw)
    {
        var value = ExtractProfile(raw);
        if (string.IsNullOrWhiteSpace(value)) return false;
        var lower = value.TrimStart().ToLowerInvariant();
        return lower.StartsWith("{", StringComparison.Ordinal)
               || lower.StartsWith("xray://", StringComparison.Ordinal)
               || lower.StartsWith("vless://", StringComparison.Ordinal)
               || lower.StartsWith("vmess://", StringComparison.Ordinal)
               || lower.StartsWith("trojan://", StringComparison.Ordinal)
               || lower.StartsWith("ss://", StringComparison.Ordinal)
               || lower.StartsWith("socks://", StringComparison.Ordinal)
               || lower.StartsWith("http-proxy://", StringComparison.Ordinal);
    }

    public static XrayProfile Parse(string? raw, int socksPort)
    {
        var value = ExtractProfile(raw);
        if (string.IsNullOrWhiteSpace(value)) throw new ArgumentException("empty Xray profile");

        var trimmed = value.Trim();
        var lower = trimmed.ToLowerInvariant();
        if (trimmed.StartsWith("{", StringComparison.Ordinal))
        {
            return new XrayProfile("Xray JSON", "json", EnsureLocalSocksInbound(trimmed, socksPort));
        }

        if (lower.StartsWith("xray://", StringComparison.Ordinal))
        {
            var payload = trimmed["xray://".Length..].Trim();
            var json = DecodeProfilePayload(payload);
            if (!json.TrimStart().StartsWith("{", StringComparison.Ordinal))
            {
                throw new ArgumentException("xray:// payload must be URL-encoded or base64url JSON");
            }
            return new XrayProfile("Xray JSON", "json", EnsureLocalSocksInbound(json, socksPort));
        }

        if (lower.StartsWith("vmess://", StringComparison.Ordinal)) return ParseVmess(trimmed, socksPort);
        if (lower.StartsWith("vless://", StringComparison.Ordinal)) return ParseUriOutbound(trimmed, "vless", socksPort);
        if (lower.StartsWith("trojan://", StringComparison.Ordinal)) return ParseUriOutbound(trimmed, "trojan", socksPort);
        if (lower.StartsWith("ss://", StringComparison.Ordinal)) return ParseShadowsocks(trimmed, socksPort);
        if (lower.StartsWith("socks://", StringComparison.Ordinal)) return ParseUriOutbound(trimmed, "socks", socksPort);
        if (lower.StartsWith("http-proxy://", StringComparison.Ordinal)) return ParseHttpProxy(trimmed, socksPort);

        throw new ArgumentException("unsupported Xray profile format");
    }

    private static XrayProfile ParseUriOutbound(string raw, string protocol, int socksPort)
    {
        var uri = new Uri(raw, UriKind.Absolute);
        var query = ParseQuery(uri.Query);
        var host = FirstNonEmpty(uri.IdnHost, uri.Host);
        var port = uri.Port > 0 ? uri.Port : DefaultPort(query);
        var name = FirstNonEmpty(Uri.UnescapeDataString(uri.Fragment.TrimStart('#')), host, protocol);

        JsonObject outbound = protocol switch
        {
            "vless" => new JsonObject
            {
                ["protocol"] = "vless",
                ["tag"] = "proxy",
                ["settings"] = new JsonObject
                {
                    ["vnext"] = new JsonArray(new JsonObject
                    {
                        ["address"] = host,
                        ["port"] = port,
                        ["users"] = new JsonArray(new JsonObject
                        {
                            ["id"] = Uri.UnescapeDataString(uri.UserInfo),
                            ["encryption"] = FirstNonEmpty(Get(query, "encryption"), "none"),
                            ["flow"] = EmptyToNull(Get(query, "flow"))
                        })
                    })
                }
            },
            "trojan" => new JsonObject
            {
                ["protocol"] = "trojan",
                ["tag"] = "proxy",
                ["settings"] = new JsonObject
                {
                    ["servers"] = new JsonArray(new JsonObject
                    {
                        ["address"] = host,
                        ["port"] = port,
                        ["password"] = Uri.UnescapeDataString(uri.UserInfo)
                    })
                }
            },
            "socks" => BuildSocksOutbound(uri, host, port),
            _ => throw new ArgumentException("unsupported Xray URI protocol: " + protocol)
        };

        AddStreamSettings(outbound, query);
        return new XrayProfile(name, protocol, BuildClientConfig(outbound, socksPort));
    }

    private static XrayProfile ParseHttpProxy(string raw, int socksPort)
    {
        var proxyUri = "http://" + raw["http-proxy://".Length..];
        var uri = new Uri(proxyUri, UriKind.Absolute);
        var query = ParseQuery(uri.Query);
        var host = FirstNonEmpty(uri.IdnHost, uri.Host);
        var port = uri.Port > 0 ? uri.Port : 8080;
        var users = new JsonArray();
        if (!string.IsNullOrWhiteSpace(uri.UserInfo))
        {
            var parts = Uri.UnescapeDataString(uri.UserInfo).Split(':', 2);
            users.Add(new JsonObject
            {
                ["user"] = parts[0],
                ["pass"] = parts.Length > 1 ? parts[1] : ""
            });
        }

        var outbound = new JsonObject
        {
            ["protocol"] = "http",
            ["tag"] = "proxy",
            ["settings"] = new JsonObject
            {
                ["servers"] = new JsonArray(new JsonObject
                {
                    ["address"] = host,
                    ["port"] = port,
                    ["users"] = users
                })
            }
        };
        AddStreamSettings(outbound, query);
        return new XrayProfile(FirstNonEmpty(Uri.UnescapeDataString(uri.Fragment.TrimStart('#')), host, "http"), "http", BuildClientConfig(outbound, socksPort));
    }

    private static XrayProfile ParseVmess(string raw, int socksPort)
    {
        var payload = raw["vmess://".Length..].Trim();
        var json = DecodeBase64Loose(payload);
        var node = JsonNode.Parse(json) as JsonObject ?? throw new ArgumentException("bad vmess payload");
        var host = NodeString(node, "add");
        var port = NodeInt(node, "port", 443);
        var id = NodeString(node, "id");
        var name = FirstNonEmpty(NodeString(node, "ps"), host, "vmess");

        var outbound = new JsonObject
        {
            ["protocol"] = "vmess",
            ["tag"] = "proxy",
            ["settings"] = new JsonObject
            {
                ["vnext"] = new JsonArray(new JsonObject
                {
                    ["address"] = host,
                    ["port"] = port,
                    ["users"] = new JsonArray(new JsonObject
                    {
                        ["id"] = id,
                        ["alterId"] = NodeInt(node, "aid", 0),
                        ["security"] = FirstNonEmpty(NodeString(node, "scy"), "auto")
                    })
                })
            }
        };

        var query = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["type"] = FirstNonEmpty(NodeString(node, "net"), "tcp"),
            ["security"] = FirstNonEmpty(NodeString(node, "tls"), "none"),
            ["sni"] = NodeString(node, "sni"),
            ["host"] = NodeString(node, "host"),
            ["path"] = NodeString(node, "path"),
            ["alpn"] = NodeString(node, "alpn"),
            ["fp"] = NodeString(node, "fp")
        };
        AddStreamSettings(outbound, query);
        return new XrayProfile(name, "vmess", BuildClientConfig(outbound, socksPort));
    }

    private static XrayProfile ParseShadowsocks(string raw, int socksPort)
    {
        var body = raw["ss://".Length..];
        var fragmentIndex = body.IndexOf('#');
        var name = "";
        if (fragmentIndex >= 0)
        {
            name = Uri.UnescapeDataString(body[(fragmentIndex + 1)..]);
            body = body[..fragmentIndex];
        }
        var queryIndex = body.IndexOf('?');
        if (queryIndex >= 0) body = body[..queryIndex];

        string userInfo;
        string server;
        var at = body.LastIndexOf('@');
        if (at >= 0)
        {
            userInfo = body[..at];
            server = body[(at + 1)..];
            if (!userInfo.Contains(':')) userInfo = DecodeBase64Loose(userInfo);
            else userInfo = Uri.UnescapeDataString(userInfo);
        }
        else
        {
            var decoded = DecodeBase64Loose(body);
            at = decoded.LastIndexOf('@');
            if (at < 0) throw new ArgumentException("bad ss link");
            userInfo = decoded[..at];
            server = decoded[(at + 1)..];
        }

        var auth = userInfo.Split(':', 2);
        if (auth.Length != 2) throw new ArgumentException("bad ss credentials");
        var hostPort = SplitHostPort(server);
        var outbound = new JsonObject
        {
            ["protocol"] = "shadowsocks",
            ["tag"] = "proxy",
            ["settings"] = new JsonObject
            {
                ["servers"] = new JsonArray(new JsonObject
                {
                    ["address"] = hostPort.Host,
                    ["port"] = hostPort.Port,
                    ["method"] = auth[0],
                    ["password"] = auth[1]
                })
            }
        };
        return new XrayProfile(FirstNonEmpty(name, hostPort.Host, "shadowsocks"), "shadowsocks", BuildClientConfig(outbound, socksPort));
    }

    private static JsonObject BuildSocksOutbound(Uri uri, string host, int port)
    {
        var servers = new JsonArray();
        var server = new JsonObject { ["address"] = host, ["port"] = port };
        if (!string.IsNullOrWhiteSpace(uri.UserInfo))
        {
            var parts = Uri.UnescapeDataString(uri.UserInfo).Split(':', 2);
            server["users"] = new JsonArray(new JsonObject
            {
                ["user"] = parts[0],
                ["pass"] = parts.Length > 1 ? parts[1] : ""
            });
        }
        servers.Add(server);
        return new JsonObject
        {
            ["protocol"] = "socks",
            ["tag"] = "proxy",
            ["settings"] = new JsonObject { ["servers"] = servers }
        };
    }

    private static void AddStreamSettings(JsonObject outbound, IReadOnlyDictionary<string, string> query)
    {
        var network = FirstNonEmpty(Get(query, "type"), Get(query, "network"), "tcp").ToLowerInvariant();
        var security = FirstNonEmpty(Get(query, "security"), "none").ToLowerInvariant();
        var stream = new JsonObject { ["network"] = network };
        if (!string.IsNullOrWhiteSpace(security) && security != "none")
        {
            stream["security"] = security;
            if (security == "tls")
            {
                stream["tlsSettings"] = new JsonObject
                {
                    ["serverName"] = EmptyToNull(FirstNonEmpty(Get(query, "sni"), Get(query, "serverName"))),
                    ["allowInsecure"] = ParseBool(Get(query, "allowInsecure"))
                };
            }
            else if (security == "reality")
            {
                stream["realitySettings"] = new JsonObject
                {
                    ["serverName"] = EmptyToNull(FirstNonEmpty(Get(query, "sni"), Get(query, "serverName"))),
                    ["fingerprint"] = EmptyToNull(Get(query, "fp")),
                    ["publicKey"] = EmptyToNull(Get(query, "pbk")),
                    ["shortId"] = EmptyToNull(Get(query, "sid")),
                    ["spiderX"] = EmptyToNull(Get(query, "spx"))
                };
            }
        }

        if (network == "ws")
        {
            stream["wsSettings"] = new JsonObject
            {
                ["path"] = EmptyToNull(Get(query, "path")),
                ["headers"] = new JsonObject { ["Host"] = EmptyToNull(Get(query, "host")) }
            };
        }
        else if (network == "grpc")
        {
            stream["grpcSettings"] = new JsonObject { ["serviceName"] = EmptyToNull(Get(query, "serviceName")) };
        }
        else if (network is "http" or "h2")
        {
            stream["network"] = "http";
            stream["httpSettings"] = new JsonObject
            {
                ["path"] = EmptyToNull(Get(query, "path")),
                ["host"] = HostArray(Get(query, "host"))
            };
        }
        else if (network is "xhttp" or "splithttp")
        {
            stream["network"] = network;
            stream[network + "Settings"] = new JsonObject
            {
                ["path"] = EmptyToNull(Get(query, "path")),
                ["host"] = EmptyToNull(Get(query, "host")),
                ["mode"] = EmptyToNull(Get(query, "mode"))
            };
        }
        else if (network == "kcp")
        {
            stream["kcpSettings"] = new JsonObject
            {
                ["header"] = new JsonObject { ["type"] = FirstNonEmpty(Get(query, "headerType"), Get(query, "header"), "none") }
            };
        }
        else if (network == "quic")
        {
            stream["quicSettings"] = new JsonObject
            {
                ["security"] = EmptyToNull(Get(query, "quicSecurity")),
                ["key"] = EmptyToNull(Get(query, "key")),
                ["header"] = new JsonObject { ["type"] = FirstNonEmpty(Get(query, "headerType"), Get(query, "header"), "none") }
            };
        }

        outbound["streamSettings"] = stream;
    }

    private static string BuildClientConfig(JsonObject outbound, int socksPort)
    {
        var root = new JsonObject
        {
            ["log"] = new JsonObject { ["loglevel"] = "warning" },
            ["inbounds"] = new JsonArray(BuildSocksInbound(socksPort)),
            ["outbounds"] = new JsonArray(
                outbound,
                new JsonObject { ["tag"] = "direct", ["protocol"] = "freedom" },
                new JsonObject { ["tag"] = "block", ["protocol"] = "blackhole" }),
            ["routing"] = new JsonObject
            {
                ["domainStrategy"] = "IPIfNonMatch",
                ["rules"] = new JsonArray()
            }
        };
        return root.ToJsonString(JsonOptions);
    }

    private static string EnsureLocalSocksInbound(string json, int socksPort)
    {
        var root = JsonNode.Parse(json) as JsonObject ?? throw new ArgumentException("Xray config must be a JSON object");
        root["log"] ??= new JsonObject { ["loglevel"] = "warning" };
        var existing = root["inbounds"] as JsonArray;
        var next = new JsonArray { BuildSocksInbound(socksPort) };
        if (existing != null)
        {
            foreach (var item in existing)
            {
                if (item == null) continue;
                var clone = item.DeepClone();
                if (clone is JsonObject obj && string.Equals(NodeString(obj, "tag"), "xltd-socks-in", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
                next.Add(clone);
            }
        }
        root["inbounds"] = next;
        return root.ToJsonString(JsonOptions);
    }

    private static JsonObject BuildSocksInbound(int socksPort)
    {
        return new JsonObject
        {
            ["tag"] = "xltd-socks-in",
            ["listen"] = AppInfo.DefaultSocksHost,
            ["port"] = socksPort,
            ["protocol"] = "socks",
            ["settings"] = new JsonObject { ["auth"] = "noauth", ["udp"] = true },
            ["sniffing"] = new JsonObject
            {
                ["enabled"] = true,
                ["destOverride"] = new JsonArray("http", "tls", "quic")
            }
        };
    }

    private static Dictionary<string, string> ParseQuery(string query)
    {
        var output = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        query = query.TrimStart('?');
        if (string.IsNullOrWhiteSpace(query)) return output;
        foreach (var pair in query.Split('&', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var eq = pair.IndexOf('=');
            var key = eq >= 0 ? pair[..eq] : pair;
            var value = eq >= 0 ? pair[(eq + 1)..] : "";
            key = Uri.UnescapeDataString(key);
            value = Uri.UnescapeDataString(value);
            if (!string.IsNullOrWhiteSpace(key)) output[key] = value;
        }
        return output;
    }

    private static string ExtractProfile(string? raw)
    {
        var value = (raw ?? "").Trim();
        if (value.Length == 0) return value;
        var schemes = new[] { "xray://", "vless://", "vmess://", "trojan://", "ss://", "socks://", "http-proxy://", "{" };
        var lower = value.ToLowerInvariant();
        var start = schemes
            .Select(s => lower.IndexOf(s, StringComparison.Ordinal))
            .Where(i => i >= 0)
            .DefaultIfEmpty(-1)
            .Min();
        if (start > 0) value = value[start..].Trim();
        var lineEnd = value.IndexOfAny(['\r', '\n']);
        return lineEnd >= 0 ? value[..lineEnd].Trim() : value;
    }

    private static string DecodeProfilePayload(string payload)
    {
        payload = Uri.UnescapeDataString(payload.Trim());
        if (payload.StartsWith("{", StringComparison.Ordinal)) return payload;
        return DecodeBase64Loose(payload);
    }

    private static string DecodeBase64Loose(string encoded)
    {
        encoded = encoded.Trim().Replace('-', '+').Replace('_', '/');
        encoded = encoded.Split('?', '#')[0];
        var mod = encoded.Length % 4;
        if (mod > 0) encoded = encoded.PadRight(encoded.Length + 4 - mod, '=');
        return Encoding.UTF8.GetString(Convert.FromBase64String(encoded));
    }

    private static JsonArray? HostArray(string host)
    {
        if (string.IsNullOrWhiteSpace(host)) return null;
        var arr = new JsonArray();
        foreach (var part in host.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            arr.Add(part);
        }
        return arr.Count == 0 ? null : arr;
    }

    private static (string Host, int Port) SplitHostPort(string value)
    {
        value = Uri.UnescapeDataString(value);
        if (value.StartsWith("[", StringComparison.Ordinal))
        {
            var end = value.IndexOf(']');
            if (end > 0 && value.Length > end + 2 && value[end + 1] == ':')
            {
                return (value[1..end], int.Parse(value[(end + 2)..]));
            }
        }
        var colon = value.LastIndexOf(':');
        if (colon <= 0 || colon + 1 >= value.Length) throw new ArgumentException("missing host:port");
        return (value[..colon], int.Parse(value[(colon + 1)..]));
    }

    private static int DefaultPort(IReadOnlyDictionary<string, string> query)
    {
        var security = FirstNonEmpty(Get(query, "security"), "none");
        return security is "tls" or "reality" ? 443 : 80;
    }

    private static string Get(IReadOnlyDictionary<string, string> map, string key)
    {
        return map.TryGetValue(key, out var value) ? value : "";
    }

    private static string NodeString(JsonObject node, string key)
    {
        return node.TryGetPropertyValue(key, out var value) ? value?.ToString() ?? "" : "";
    }

    private static int NodeInt(JsonObject node, string key, int fallback)
    {
        var raw = NodeString(node, key);
        return int.TryParse(raw, out var parsed) ? parsed : fallback;
    }

    private static JsonNode? EmptyToNull(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : JsonValue.Create(value.Trim());
    }

    private static bool ParseBool(string value)
    {
        return value.Equals("1", StringComparison.OrdinalIgnoreCase)
               || value.Equals("true", StringComparison.OrdinalIgnoreCase)
               || value.Equals("yes", StringComparison.OrdinalIgnoreCase);
    }

    private static string FirstNonEmpty(params string?[] values)
    {
        foreach (var value in values)
        {
            if (!string.IsNullOrWhiteSpace(value)) return value.Trim();
        }
        return "";
    }
}
