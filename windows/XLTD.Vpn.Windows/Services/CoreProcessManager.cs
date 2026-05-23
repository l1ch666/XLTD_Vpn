using System.Diagnostics;
using System.Net.Sockets;
using System.Text;
using XLTD.Vpn.Windows.Models;

namespace XLTD.Vpn.Windows.Services;

internal sealed class CoreProcessManager : IDisposable
{
    private Process? process;

    public event Action<string>? LogLine;
    public event Action<int?>? Exited;

    public bool IsRunning => process is { HasExited: false };

    public void Start(OlcConfig config, int socksPort)
    {
        if (IsRunning) throw new InvalidOperationException("Core is already running");

        var exe = ResolveToolPath("olcrtc.exe");
        var configPath = WriteRuntimeConfig(config, socksPort);

        var startInfo = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = QuoteArgument(configPath),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = Path.GetDirectoryName(exe) ?? AppContext.BaseDirectory
        };
        startInfo.Environment["PION_LOG_DISABLE"] = "all";
        if (IsMtsLink(config))
        {
            ApplyMtsLinkEnvironment(startInfo, config);
        }

        process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.OutputDataReceived += (_, args) => Publish(args.Data);
        process.ErrorDataReceived += (_, args) => Publish(args.Data);
        process.Exited += (_, _) =>
        {
            var code = TryGetExitCode();
            Exited?.Invoke(code);
        };

        if (!process.Start())
        {
            process = null;
            throw new InvalidOperationException("Failed to start olcrtc.exe");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        Publish("olcrtc.exe started");
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
        if (current == null)
        {
            return;
        }

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
            Publish("stop error: " + ex.Message);
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

    private static string ResolveToolPath(string fileName)
    {
        var bundled = Path.Combine(AppContext.BaseDirectory, "tools", fileName);
        if (File.Exists(bundled)) return bundled;

        var local = Path.Combine(AppContext.BaseDirectory, fileName);
        if (File.Exists(local)) return local;

        throw new FileNotFoundException($"Missing {fileName}. Rebuild the Windows package with scripts/build_windows.ps1.", bundled);
    }

    private static string WriteRuntimeConfig(OlcConfig config, int socksPort)
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "XLTD_Vpn",
            "runtime");
        Directory.CreateDirectory(dir);

        var dataDir = Path.Combine(AppContext.BaseDirectory, "tools", "data");
        var path = Path.Combine(dir, "client.yaml");
        File.WriteAllText(path, BuildYaml(config, socksPort, dataDir), Encoding.UTF8);
        return path;
    }

    private static string BuildYaml(OlcConfig config, int socksPort, string dataDir)
    {
        var dns = config.Param("dns", AppInfo.DefaultDns);
        var isMtsLink = IsMtsLink(config);
        var sb = new StringBuilder();
        sb.AppendLine("mode: cnc");
        sb.AppendLine("auth:");
        sb.AppendLine($"  provider: {Yaml(config.Carrier)}");
        sb.AppendLine("room:");
        sb.AppendLine($"  id: {Yaml(config.RoomId)}");
        sb.AppendLine($"  channel: {Yaml(config.ClientId)}");
        sb.AppendLine("crypto:");
        sb.AppendLine($"  key: {Yaml(config.KeyHex)}");
        sb.AppendLine("net:");
        sb.AppendLine($"  transport: {Yaml(config.Transport)}");
        sb.AppendLine($"  dns: {Yaml(dns)}");
        sb.AppendLine("socks:");
        sb.AppendLine($"  host: {Yaml(AppInfo.DefaultSocksHost)}");
        sb.AppendLine($"  port: {socksPort}");
        sb.AppendLine("liveness:");
        sb.AppendLine($"  interval: {Yaml(config.Param("liveness-interval", isMtsLink ? "20s" : "10s"))}");
        sb.AppendLine($"  timeout: {Yaml(config.Param("liveness-timeout", isMtsLink ? "15s" : "5s"))}");
        sb.AppendLine($"  failures: {config.IntParam("liveness-failures", isMtsLink ? 6 : 3)}");
        AppendTrafficOptions(sb, config, isMtsLink);
        AppendTransportOptions(sb, config);
        if (config.Transport == OlcUriParser.TransportVideo)
        {
            sb.AppendLine($"ffmpeg: {Yaml(ResolveToolPath("ffmpeg.exe"))}");
        }
        sb.AppendLine($"data: {Yaml(dataDir)}");
        sb.AppendLine("debug: false");
        return sb.ToString();
    }

    private static bool IsMtsLink(OlcConfig config)
    {
        return string.Equals(config.Carrier, "mtslink", StringComparison.OrdinalIgnoreCase);
    }

    private static void ApplyMtsLinkEnvironment(ProcessStartInfo startInfo, OlcConfig config)
    {
        SetEnvIfNotEmpty(startInfo, "MTS_FORCE_VIDEO", config.Param("mts-force-video", "1"));
        SetEnvIfNotEmpty(startInfo, "MTS_PEER_UPDATE", config.Param("mts-peer-update", "1"));
        SetEnvIfNotEmpty(startInfo, "MTS_SILENT_AUDIO", config.Param("mts-silent-audio", "1"));
        SetEnvIfNotEmpty(startInfo, "MTS_VIDEO_TEST", config.Param("mts-video-test", ""));
        SetEnvIfNotEmpty(startInfo, "MTS_VIDEO_CODEC", config.Param("mts-video-codec", ""));
    }

    private static void SetEnvIfNotEmpty(ProcessStartInfo startInfo, string name, string value)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            startInfo.Environment[name] = value.Trim();
        }
    }

    private static void AppendTransportOptions(StringBuilder sb, OlcConfig config)
    {
        if (config.Transport == OlcUriParser.TransportVp8)
        {
            sb.AppendLine("vp8:");
            sb.AppendLine($"  fps: {config.IntParam("vp8-fps", config.IntParam("fps", 25))}");
            sb.AppendLine($"  batch_size: {config.IntParam("vp8-batch", config.IntParam("batch", 1))}");
            return;
        }

        if (config.Transport == OlcUriParser.TransportSei)
        {
            var isMtsLink = string.Equals(config.Carrier, "mtslink", StringComparison.OrdinalIgnoreCase);
            sb.AppendLine("sei:");
            sb.AppendLine($"  fps: {config.IntParam("fps", config.IntParam("sei-fps", isMtsLink ? 30 : 60))}");
            sb.AppendLine($"  batch_size: {config.IntParam("batch", config.IntParam("sei-batch", isMtsLink ? 8 : 64))}");
            sb.AppendLine($"  fragment_size: {config.IntParam("frag", config.IntParam("sei-frag", isMtsLink ? 700 : 900))}");
            sb.AppendLine($"  ack_timeout_ms: {config.IntParam("ack-ms", config.IntParam("sei-ack-ms", isMtsLink ? 10000 : 2000))}");
            return;
        }

        if (config.Transport == OlcUriParser.TransportVideo)
        {
            var isMtsLink = string.Equals(config.Carrier, "mtslink", StringComparison.OrdinalIgnoreCase);
            sb.AppendLine("video:");
            sb.AppendLine($"  codec: {Yaml(config.Param("video-codec", "qrcode"))}");
            sb.AppendLine($"  width: {config.IntParam("video-w", config.IntParam("video-width", isMtsLink ? 640 : 1080))}");
            sb.AppendLine($"  height: {config.IntParam("video-h", config.IntParam("video-height", isMtsLink ? 360 : 1080))}");
            sb.AppendLine($"  fps: {config.IntParam("video-fps", isMtsLink ? 15 : 60)}");
            sb.AppendLine($"  bitrate: {Yaml(config.Param("video-bitrate", isMtsLink ? "1200k" : "5000k"))}");
            sb.AppendLine($"  hw: {Yaml(config.Param("video-hw", "none"))}");
            sb.AppendLine($"  qr_size: {config.IntParam("video-qr-size", 0)}");
            sb.AppendLine($"  qr_recovery: {Yaml(config.Param("video-qr-recovery", "low"))}");
            sb.AppendLine($"  tile_module: {config.IntParam("video-tile-module", 4)}");
            sb.AppendLine($"  tile_rs: {config.IntParam("video-tile-rs", 20)}");
        }
    }

    private static void AppendTrafficOptions(StringBuilder sb, OlcConfig config, bool isMtsLink)
    {
        var maxPayload = config.IntParam("traffic-max-payload", config.IntParam("traffic-max-payload-size", 0));
        var minDelay = config.Param("traffic-min-delay", "");
        var maxDelay = config.Param("traffic-max-delay", "");
        if (maxPayload <= 0 && string.IsNullOrWhiteSpace(minDelay) && string.IsNullOrWhiteSpace(maxDelay))
        {
            return;
        }

        sb.AppendLine("traffic:");
        if (maxPayload > 0)
        {
            sb.AppendLine($"  max_payload_size: {maxPayload}");
        }
        if (!string.IsNullOrWhiteSpace(minDelay))
        {
            sb.AppendLine($"  min_delay: {Yaml(minDelay)}");
        }
        if (!string.IsNullOrWhiteSpace(maxDelay))
        {
            sb.AppendLine($"  max_delay: {Yaml(maxDelay)}");
        }
    }

    private static string Yaml(string value)
    {
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }

    private static string QuoteArgument(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static async Task<bool> TrySocksHandshakeAsync(int port, CancellationToken cancellationToken)
    {
        try
        {
            using var client = new TcpClient();
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(2));
            await client.ConnectAsync(AppInfo.DefaultSocksHost, port, timeout.Token).ConfigureAwait(false);
            await using var stream = client.GetStream();
            await stream.WriteAsync(new byte[] { 0x05, 0x01, 0x00 }, timeout.Token).ConfigureAwait(false);
            var buffer = new byte[2];
            var read = await stream.ReadAsync(buffer, timeout.Token).ConfigureAwait(false);
            return read == 2 && buffer[0] == 0x05 && buffer[1] == 0x00;
        }
        catch
        {
            return false;
        }
    }

    private int? TryGetExitCode()
    {
        try
        {
            return process?.ExitCode;
        }
        catch
        {
            return null;
        }
    }

    private void Publish(string? line)
    {
        if (!string.IsNullOrWhiteSpace(line)) LogLine?.Invoke(line);
    }
}
