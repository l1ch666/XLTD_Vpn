using System.Diagnostics;
using System.Security.Principal;

namespace XLTD.Vpn.Windows.Services;

internal sealed class WindowsTunnelManager : IDisposable
{
    private const string AdapterName = "XLTDVpn";
    private const string TunAddress = "198.18.0.1";
    private const int PrefixLength = 15;

    private Process? process;
    private int? interfaceIndex;

    public event Action<string>? LogLine;

    public bool IsRunning => process is { HasExited: false };

    public static bool IsAdministrator()
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    public void Start(int socksPort, int mtu)
    {
        if (IsRunning) throw new InvalidOperationException("Tunnel is already running");
        if (!IsAdministrator())
        {
            throw new InvalidOperationException("Full tunnel requires running XLTD VPN as Administrator");
        }

        var exe = ResolveToolPath("tun2socks.exe");
        var toolsDir = Path.GetDirectoryName(exe) ?? AppContext.BaseDirectory;
        _ = ResolveToolPath("wintun.dll");
        var args = $"--device tun://{AdapterName} --proxy socks5://{AppInfo.DefaultSocksHost}:{socksPort} --mtu {mtu} --loglevel info";
        var startInfo = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = toolsDir
        };
        startInfo.Environment["PATH"] = toolsDir + Path.PathSeparator + (startInfo.Environment.TryGetValue("PATH", out var path) ? path : "");

        process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.OutputDataReceived += (_, e) => Publish(e.Data);
        process.ErrorDataReceived += (_, e) => Publish(e.Data);
        process.Exited += (_, _) => Publish("tun2socks exited");

        if (!process.Start())
        {
            process = null;
            throw new InvalidOperationException("Failed to start tun2socks.exe");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        Publish("tun2socks.exe started");

        Thread.Sleep(1800);
        if (process.HasExited)
        {
            throw new InvalidOperationException("tun2socks exited before creating the TUN adapter. Check Runtime log for Wintun or driver errors.");
        }
        ConfigureInterface();
    }

    public void Stop()
    {
        RestoreInterface();
        var current = process;
        if (current == null) return;

        try
        {
            if (!current.HasExited)
            {
                current.Kill(entireProcessTree: true);
                current.WaitForExit(3000);
            }
        }
        catch (Exception ex)
        {
            Publish("tunnel stop error: " + ex.Message);
        }
        finally
        {
            current.Dispose();
            if (ReferenceEquals(process, current)) process = null;
        }
    }

    public void Dispose()
    {
        Stop();
    }

    private void ConfigureInterface()
    {
        var script = $$"""
$ErrorActionPreference = 'Stop'
$adapter = Get-NetAdapter -Name '{{AdapterName}}' -ErrorAction SilentlyContinue
if ($null -eq $adapter) {
    $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wintun*' -or $_.InterfaceDescription -like '*WireGuard*' } | Sort-Object ifIndex -Descending | Select-Object -First 1
}
if ($null -eq $adapter) { throw 'TUN adapter was not found after tun2socks start' }
$idx = $adapter.ifIndex
Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $idx -IPAddress '{{TunAddress}}' -PrefixLength {{PrefixLength}} -AddressFamily IPv4 | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses ('1.1.1.1','8.8.8.8')
Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '0.0.0.0/1' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '128.0.0.0/1' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
New-NetRoute -InterfaceIndex $idx -DestinationPrefix '0.0.0.0/1' -NextHop '0.0.0.0' -RouteMetric 1 | Out-Null
New-NetRoute -InterfaceIndex $idx -DestinationPrefix '128.0.0.0/1' -NextHop '0.0.0.0' -RouteMetric 1 | Out-Null
Write-Output $idx
""";

        var output = RunPowerShell(script);
        var last = output.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries).LastOrDefault();
        if (int.TryParse(last, out var idx)) interfaceIndex = idx;
        Publish("full tunnel routes applied on interface " + (interfaceIndex?.ToString() ?? "unknown"));
    }

    private void RestoreInterface()
    {
        if (interfaceIndex == null) return;
        var idx = interfaceIndex.Value;
        var script = $$"""
$idx = {{idx}}
Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '0.0.0.0/1' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
Get-NetRoute -InterfaceIndex $idx -DestinationPrefix '128.0.0.0/1' -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
Get-NetIPAddress -InterfaceIndex $idx -IPAddress '{{TunAddress}}' -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction SilentlyContinue
""";

        try
        {
            _ = RunPowerShell(script);
            Publish("full tunnel routes restored");
        }
        catch (Exception ex)
        {
            Publish("full tunnel restore error: " + ex.Message);
        }
        finally
        {
            interfaceIndex = null;
        }
    }

    private static string ResolveToolPath(string fileName)
    {
        var bundled = Path.Combine(AppContext.BaseDirectory, "tools", fileName);
        if (File.Exists(bundled)) return bundled;
        var hint = fileName.Equals("wintun.dll", StringComparison.OrdinalIgnoreCase)
            ? "Missing wintun.dll. Rebuild the Windows package with scripts/build_windows.ps1, or place the official Wintun DLL next to tun2socks.exe."
            : $"Missing {fileName}. Rebuild the Windows package with scripts/build_windows.ps1.";
        throw new FileNotFoundException(hint, bundled);
    }

    private static string RunPowerShell(string script)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -Command " + Quote(script),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var ps = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start PowerShell");
        var stdout = ps.StandardOutput.ReadToEnd();
        var stderr = ps.StandardError.ReadToEnd();
        ps.WaitForExit();
        if (ps.ExitCode != 0)
        {
            throw new InvalidOperationException(stderr.Trim().Length > 0 ? stderr.Trim() : stdout.Trim());
        }

        return stdout.Trim();
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private void Publish(string? line)
    {
        if (!string.IsNullOrWhiteSpace(line)) LogLine?.Invoke(line);
    }
}
