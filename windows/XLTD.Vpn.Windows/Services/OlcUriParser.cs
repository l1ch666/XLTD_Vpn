using System.Net;
using System.Text.RegularExpressions;
using XLTD.Vpn.Windows.Models;

namespace XLTD.Vpn.Windows.Services;

internal static class OlcUriParser
{
    public const string TransportData = "datachannel";
    public const string TransportVp8 = "vp8channel";
    public const string TransportSei = "seichannel";
    public const string TransportVideo = "videochannel";

    private const string Scheme = "olcrtc://";
    private const string DefaultClientId = "default";

    public static OlcConfig Parse(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            throw new ArgumentException("empty link");
        }

        var value = ExtractUri(raw);
        if (!value.StartsWith(Scheme, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("link must start with olcrtc://");
        }

        var body = value[Scheme.Length..];
        var q = body.IndexOf('?');
        var at = q >= 0 ? body.IndexOf('@', q + 1) : -1;
        var hash = at >= 0 ? body.IndexOf('#', at + 1) : -1;

        if (q <= 0) throw new ArgumentException("missing carrier or ?");
        if (at <= q) throw new ArgumentException("missing transport or @");
        if (hash <= at) throw new ArgumentException("missing roomId or #");

        var carrier = Decode(body[..q]).Trim().ToLowerInvariant();
        var transportParts = ParseTransportSpec(body[(q + 1)..at].Trim());
        var transport = NormalizeTransport(transportParts.Transport);
        EnsureSupportedTransport(transport);

        var roomId = Decode(body[(at + 1)..hash].Trim());
        var tail = ParseTail(body[(hash + 1)..]);
        var clientId = string.IsNullOrWhiteSpace(tail.ClientId)
            ? FirstNonEmpty(
                transportParts.Parameters.GetValueOrDefault("client-id"),
                transportParts.Parameters.GetValueOrDefault("clientid"),
                transportParts.Parameters.GetValueOrDefault("client"),
                DefaultClientId)
            : tail.ClientId.Trim();

        if (carrier.Length == 0) throw new ArgumentException("carrier is empty");
        if (transport.Length == 0) throw new ArgumentException("transport is empty");
        if (roomId.Length == 0 && carrier != "jazz") throw new ArgumentException("roomId is empty");
        if (clientId.Length == 0) throw new ArgumentException("clientId is empty");
        if (tail.KeyHex.Length != 64) throw new ArgumentException("keyHex must be 64 hex chars");
        if (!Regex.IsMatch(tail.KeyHex, "^[0-9a-fA-F]{64}$")) throw new ArgumentException("keyHex is not hex");

        return new OlcConfig(
            carrier,
            transport,
            roomId,
            tail.KeyHex,
            clientId,
            tail.Comment,
            transportParts.Parameters);
    }

    public static bool IsSupportedTransport(string transport)
    {
        return transport is TransportData or TransportVp8 or TransportSei or TransportVideo;
    }

    private static string ExtractUri(string raw)
    {
        var value = raw.Trim();
        var start = value.IndexOf(Scheme, StringComparison.OrdinalIgnoreCase);
        if (start < 0)
        {
            return value;
        }

        value = value[start..].Trim();
        var lineEnd = value.IndexOfAny(['\r', '\n']);
        return lineEnd >= 0 ? value[..lineEnd].Trim() : value;
    }

    private static TransportParts ParseTransportSpec(string spec)
    {
        if (string.IsNullOrWhiteSpace(spec)) throw new ArgumentException("transport is empty");
        var open = spec.IndexOf('<');
        if (open < 0)
        {
            return new TransportParts(spec, new Dictionary<string, string>());
        }

        var close = spec.LastIndexOf('>');
        if (close < open || close != spec.Length - 1)
        {
            throw new ArgumentException("bad transport params: expected transport<key=value&...>");
        }

        var transport = spec[..open].Trim();
        var inside = spec[(open + 1)..close].Trim();
        return new TransportParts(transport, ParseParams(inside));
    }

    private static Dictionary<string, string> ParseParams(string raw)
    {
        var output = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(raw)) return output;

        foreach (var pair in raw.Split('&', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var eq = pair.IndexOf('=');
            var key = eq >= 0 ? pair[..eq] : pair;
            var value = eq >= 0 ? pair[(eq + 1)..] : "";
            key = Decode(key).Trim().ToLowerInvariant();
            value = Decode(value).Trim();
            if (key.Length > 0) output[key] = value;
        }

        return output;
    }

    private static TailParts ParseTail(string rawTail)
    {
        if (string.IsNullOrWhiteSpace(rawTail)) throw new ArgumentException("missing keyHex");

        var percent = rawTail.IndexOf('%');
        var dollar = rawTail.IndexOf('$');
        string key;
        var client = "";
        var comment = "";

        if (percent >= 0 && (dollar < 0 || percent < dollar))
        {
            key = rawTail[..percent];
            if (dollar > percent)
            {
                client = rawTail[(percent + 1)..dollar];
                comment = rawTail[(dollar + 1)..];
            }
            else
            {
                client = rawTail[(percent + 1)..];
            }
        }
        else if (dollar >= 0)
        {
            key = rawTail[..dollar];
            comment = rawTail[(dollar + 1)..];
        }
        else
        {
            key = rawTail;
        }

        return new TailParts(Decode(key), Decode(client), Decode(comment));
    }

    private static string NormalizeTransport(string? value)
    {
        var v = (value ?? "").Trim().ToLowerInvariant();
        return v switch
        {
            "data" or "dc" or "data_channel" or "data-channel" => TransportData,
            "vp8" or "vp8_channel" or "vp8-channel" => TransportVp8,
            "sei" or "sei_channel" or "sei-channel" => TransportSei,
            "video" or "vid" or "video_channel" or "video-channel" => TransportVideo,
            _ => v
        };
    }

    private static void EnsureSupportedTransport(string transport)
    {
        if (IsSupportedTransport(transport)) return;
        throw new ArgumentException("unsupported transport: use datachannel, vp8channel, seichannel or videochannel");
    }

    private static string Decode(string value)
    {
        try
        {
            return WebUtility.UrlDecode(value) ?? "";
        }
        catch
        {
            return value;
        }
    }

    private static string FirstNonEmpty(params string?[] values)
    {
        foreach (var value in values)
        {
            if (!string.IsNullOrWhiteSpace(value)) return value.Trim();
        }

        return "";
    }

    private sealed record TailParts(string KeyHex, string ClientId, string Comment);
    private sealed record TransportParts(string Transport, Dictionary<string, string> Parameters);
}
