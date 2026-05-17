namespace XLTD.Vpn.Windows.Models;

internal sealed class Profile
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Link { get; set; } = "";
    public string Carrier { get; set; } = "";
    public string Transport { get; set; } = "";

    public override string ToString()
    {
        var label = string.IsNullOrWhiteSpace(Name) ? "olcRTC profile" : Name;
        var meta = string.IsNullOrWhiteSpace(Carrier) ? "" : $"  [{Carrier} / {Transport}]";
        return label + meta;
    }
}
