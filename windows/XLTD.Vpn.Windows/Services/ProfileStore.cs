using System.Text.Json;
using XLTD.Vpn.Windows.Models;

namespace XLTD.Vpn.Windows.Services;

internal sealed class ProfileStore
{
    private readonly string filePath;
    private readonly JsonSerializerOptions jsonOptions = new() { WriteIndented = true };

    public ProfileStore()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "XLTD_Vpn");
        Directory.CreateDirectory(dir);
        filePath = Path.Combine(dir, "windows-profiles.json");
    }

    public List<Profile> Load()
    {
        if (!File.Exists(filePath)) return [];
        try
        {
            var json = File.ReadAllText(filePath);
            return JsonSerializer.Deserialize<List<Profile>>(json) ?? [];
        }
        catch
        {
            return [];
        }
    }

    public void Save(IReadOnlyCollection<Profile> profiles)
    {
        var ordered = profiles
            .Where(profile => !string.IsNullOrWhiteSpace(profile.Link))
            .GroupBy(profile => profile.Id)
            .Select(group => group.First())
            .ToList();
        File.WriteAllText(filePath, JsonSerializer.Serialize(ordered, jsonOptions));
    }
}
