namespace XLTD.Vpn.Windows.Models;

internal sealed class OlcConfig
{
    public OlcConfig(
        string carrier,
        string transport,
        string roomId,
        string keyHex,
        string clientId,
        string comment,
        IReadOnlyDictionary<string, string> parameters)
    {
        Carrier = carrier;
        Transport = transport;
        RoomId = roomId;
        KeyHex = keyHex;
        ClientId = clientId;
        Comment = comment;
        Parameters = parameters;
    }

    public string Carrier { get; }
    public string Transport { get; }
    public string RoomId { get; }
    public string KeyHex { get; }
    public string ClientId { get; }
    public string Comment { get; }
    public IReadOnlyDictionary<string, string> Parameters { get; }

    public string Param(string key, string fallback)
    {
        if (Parameters.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
        {
            return value.Trim();
        }

        var lower = key.ToLowerInvariant();
        if (Parameters.TryGetValue(lower, out value) && !string.IsNullOrWhiteSpace(value))
        {
            return value.Trim();
        }

        return fallback;
    }

    public int IntParam(string key, int fallback)
    {
        return int.TryParse(Param(key, string.Empty), out var value) ? value : fallback;
    }

    public string ParametersPretty()
    {
        return string.Join(", ", Parameters.Select(item => $"{item.Key}={item.Value}"));
    }
}
