using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace XLTD.Vpn.Windows.Services;

internal sealed class WindowsProxyManager
{
    private const string InternetSettingsPath = @"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
    private ProxySnapshot? snapshot;

    public bool IsApplied { get; private set; }

    public void ApplySocksProxy(string host, int port)
    {
        using var key = Registry.CurrentUser.OpenSubKey(InternetSettingsPath, writable: true)
            ?? throw new InvalidOperationException("Cannot open Windows Internet Settings registry key");

        snapshot ??= ProxySnapshot.Read(key);
        key.SetValue("ProxyEnable", 1, RegistryValueKind.DWord);
        key.SetValue("ProxyServer", $"socks={host}:{port}", RegistryValueKind.String);
        key.SetValue("ProxyOverride", "<local>", RegistryValueKind.String);
        IsApplied = true;
        RefreshSettings();
    }

    public void Restore()
    {
        if (snapshot == null || !IsApplied) return;

        using var key = Registry.CurrentUser.OpenSubKey(InternetSettingsPath, writable: true);
        if (key == null) return;

        snapshot.Restore(key);
        IsApplied = false;
        RefreshSettings();
    }

    private static void RefreshSettings()
    {
        _ = InternetSetOption(IntPtr.Zero, 39, IntPtr.Zero, 0);
        _ = InternetSetOption(IntPtr.Zero, 37, IntPtr.Zero, 0);
    }

    [DllImport("wininet.dll", SetLastError = true)]
    private static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);

    private sealed class ProxySnapshot
    {
        private readonly object? proxyEnable;
        private readonly object? proxyServer;
        private readonly object? proxyOverride;

        private ProxySnapshot(object? proxyEnable, object? proxyServer, object? proxyOverride)
        {
            this.proxyEnable = proxyEnable;
            this.proxyServer = proxyServer;
            this.proxyOverride = proxyOverride;
        }

        public static ProxySnapshot Read(RegistryKey key)
        {
            return new ProxySnapshot(
                key.GetValue("ProxyEnable"),
                key.GetValue("ProxyServer"),
                key.GetValue("ProxyOverride"));
        }

        public void Restore(RegistryKey key)
        {
            RestoreValue(key, "ProxyEnable", proxyEnable, RegistryValueKind.DWord);
            RestoreValue(key, "ProxyServer", proxyServer, RegistryValueKind.String);
            RestoreValue(key, "ProxyOverride", proxyOverride, RegistryValueKind.String);
        }

        private static void RestoreValue(RegistryKey key, string name, object? value, RegistryValueKind kind)
        {
            if (value == null)
            {
                try { key.DeleteValue(name, throwOnMissingValue: false); } catch { }
                return;
            }

            key.SetValue(name, value, kind);
        }
    }
}
