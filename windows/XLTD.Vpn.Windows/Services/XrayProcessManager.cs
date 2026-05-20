using System.Diagnostics;
using System.Net.Sockets;
using System.Text;
using XLTD.Vpn.Windows.Models;

namespace XLTD.Vpn.Windows.Services;

internal sealed class XrayProcessManager : IDisposable
{
    private Process? process;

    public event Action<string>? LogLine;
    public event Action<int?>? Exited;

    public bool IsRunning => process is { HasExited: false };

    public void Start(XrayProfile profile, int socksPort)
    {
        if (IsRunning) throw new InvalidOperationException("Xray is already running");

        var exe = ResolveToolPath("xray.exe");
        var configPath = WriteRuntimeConfig(profile);
        var startInfo = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = "run -config " + QuoteArgument(configPath) + " -format json",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = Path.GetDirectoryName(exe) ?? AppContext.BaseDirectory
        };
        var assetDir = Path.Combine(AppContext.BaseDirectory, "tools");
        startInfo.Environment["XRAY_LOCATION_ASSET"] = assetDir;

        process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.OutputDataReceived += (_, args) => Publish(args.Data);
        process.ErrorDataReceived += (_, args) => Publish(args.Data);
        process.Exited += (_, _) => Exited?.Invoke(TryGetExitCode());

        if (!process.Start())
        {
            process = null;
            throw new InvalidOperationException("Failed to start xray.exe");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        Publish($"xray.exe started ({profile.Protocol}, SOCKS 127.0.0.1:{socksPort})");
    }

    public async Task<bool> WaitForSocksAsync(int port, TimeSpan timeout, CancellationToken cancellationToken)
    {
        var started = DateTimeOffset.UtcNow;
        while (DateTimeOffset.UtcNow - started < timeout)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!IsRunning) return false;
            if (await TrySocksHandshakeAsync(port, cancellationToken).ConfigureAwait(false))
            {
                return true;
            }
            await Task.Delay(500, cancellationToken).ConfigureAwait(false);
        }
        return false;
    }

    public void Stop()
    {
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
            Publish("xray stop error: " + ex.Message);
        }
        finally
        {
            current.Dispose();
            if (ReferenceEquals(process, current)) process = null;
        }
    }

    public void Dispose() => Stop();

    private static string WriteRuntimeConfig(XrayProfile profile)
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "XLTD_Vpn",
            "runtime");
        Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, "xray-client.json");
        File.WriteAllText(path, profile.ConfigJson, Encoding.UTF8);
        return path;
    }

    private async Task<bool> TrySocksHandshakeAsync(int port, CancellationToken cancellationToken)
    {
        try
        {
            using var client = new TcpClient();
            await client.ConnectAsync(AppInfo.DefaultSocksHost, port, cancellationToken).ConfigureAwait(false);
            await using var stream = client.GetStream();
            await stream.WriteAsync(new byte[] { 0x05, 0x01, 0x00 }, cancellationToken).ConfigureAwait(false);
            var response = new byte[2];
            var read = await stream.ReadAsync(response, cancellationToken).ConfigureAwait(false);
            return read == 2 && response[0] == 0x05 && response[1] == 0x00;
        }
        catch
        {
            return false;
        }
    }

    private int? TryGetExitCode()
    {
        try { return process?.ExitCode; } catch { return null; }
    }

    private void Publish(string? line)
    {
        if (!string.IsNullOrWhiteSpace(line)) LogLine?.Invoke(line);
    }

    private static string ResolveToolPath(string fileName)
    {
        var bundled = Path.Combine(AppContext.BaseDirectory, "tools", fileName);
        if (File.Exists(bundled)) return bundled;
        var local = Path.Combine(AppContext.BaseDirectory, fileName);
        if (File.Exists(local)) return local;
        throw new FileNotFoundException($"Missing {fileName}. Rebuild the Windows alpha package with scripts/build_windows.ps1.", bundled);
    }

    private static string QuoteArgument(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
