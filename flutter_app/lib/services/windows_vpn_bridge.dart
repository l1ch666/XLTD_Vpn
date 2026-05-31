import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/connection_status.dart';
import '../models/olc_config.dart';
import '../models/transport.dart';
import 'uri_parser.dart';
import 'vpn_bridge.dart';
import 'windows_route_service.dart';

/// Windows implementation: spawns `olcrtc.exe` directly, parses stdout for
/// status hints, and polls a SOCKS handshake to detect readiness.
///
/// Mirrors the behaviour of windows/electron-app/services/core.js but in Dart.
class WindowsVpnBridge implements VpnBridge {
  Process? _proc;
  Timer? _telemetryTimer;
  DateTime? _connectedAt;
  int _routeMode = 0;
  int _latency = -1;
  bool _stopping = false;

  /// Public IPv4s the core connects to (carrier signaling + TURN relays),
  /// harvested from its ICE log. In full-tunnel mode these are pinned to the
  /// physical gateway so the core never tunnels its own transport.
  final Set<String> _corePeerIps = <String>{};
  static final RegExp _ipRe =
      RegExp(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b');
  late final WindowsRouteService _route =
      WindowsRouteService((e) => _events.add(e));

  TelemetrySnapshot _last = TelemetrySnapshot.empty;
  final _telemetry = StreamController<TelemetrySnapshot>.broadcast();
  final _events = StreamController<LogEvent>.broadcast();

  static const _socksHost = '127.0.0.1';
  static const _socksPort = 10808;
  static const _defaultDns = '1.1.1.1:53';

  @override
  Stream<TelemetrySnapshot> get telemetry async* {
    yield _last;
    yield* _telemetry.stream;
  }

  @override
  Stream<LogEvent> get events => _events.stream;

  @override
  Future<bool> healthCheck() async {
    return await _resolveTool('olcrtc.exe') != null;
  }

  @override
  Future<void> start(String olcrtcUri) async {
    if (_proc != null) {
      throw StateError('Core is already running');
    }
    _stopping = false;
    _corePeerIps.clear();
    final cfg = UriParser.parse(olcrtcUri);
    _emit(_last.copyWith(
      state: VpnState.connecting,
      carrier: cfg.carrier,
      transport: cfg.transport,
    ));

    final exe = await _resolveTool('olcrtc.exe');
    if (exe == null) {
      _emit(_last.copyWith(state: VpnState.failed, lastError: 'olcrtc.exe not found'));
      throw StateError('olcrtc.exe not found');
    }
    final runtimeDir = await _runtimeDir();
    final cfgPath = p.join(runtimeDir, 'client.yaml');
    // olcrtc resolves `data:` and `ffmpeg:` relative to its own exe dir, so the
    // data/ folder and ffmpeg.exe live next to olcrtc.exe in tools/.
    final toolsDir = p.dirname(exe);
    await File(cfgPath).writeAsString(_buildYaml(cfg, toolsDir));

    _addLog('LOG', 'core: launching olcrtc.exe');
    _proc = await Process.start(
      exe,
      [cfgPath],
      workingDirectory: toolsDir,
      environment: _coreEnv(cfg),
      runInShell: false,
    );

    _proc!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onCoreLine);
    _proc!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_onCoreLine);
    unawaited(_proc!.exitCode.then(_onCoreExit));

    final ready = await _waitForSocks(const Duration(seconds: 60));
    if (!ready) {
      await stop();
      _emit(_last.copyWith(state: VpnState.failed, lastError: 'SOCKS timeout'));
      return;
    }
    _connectedAt = DateTime.now();
    _emit(_last.copyWith(state: VpnState.connected));
    _addLog('OK', 'tunnel active · SOCKS5 $_socksHost:$_socksPort');
    _startTelemetryTimer();

    if (_routeMode == 2) {
      final pid = _proc?.pid ?? -1;
      try {
        await _route.start(
          socksHost: _socksHost,
          socksPort: _socksPort,
          corePid: pid,
          peerIps: _corePeerIps.toList(),
          dnsUpstream: cfg.strParam('dns', _defaultDns),
        );
      } catch (e) {
        // Degrade to SOCKS-only rather than killing the session; the route
        // service has already rolled back any partial routing on failure.
        _addLog('ERR', 'full tunnel: $e — оставляю SOCKS5 $_socksHost:$_socksPort');
      }
    }
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    // Tear down routing first so the physical default route is restored
    // before the core (and its loopback SOCKS listener) goes away.
    if (_route.isRunning) {
      try { await _route.stop(); } catch (_) {}
    }
    final proc = _proc;
    _proc = null;
    if (proc != null) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
      // Wait for the process to actually exit so SOCKS port 10808 is released
      // before any subsequent start() — otherwise the new core hits
      // "Only one usage of each socket address" and exits.
      try {
        await proc.exitCode.timeout(const Duration(seconds: 5));
      } catch (_) {
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
        try {
          await proc.exitCode.timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    }
    _corePeerIps.clear();
    _connectedAt = null;
    _stopping = false;
    _emit(TelemetrySnapshot.empty);
    _addLog('LOG', 'tunnel stopped');
  }

  @override
  Future<int> getRouteMode() async => _routeMode;

  @override
  Future<void> setRouteMode(int mode) async {
    _routeMode = mode;
  }

  // ── internals ──────────────────────────────────────────────────────────

  Map<String, String> _coreEnv(OlcConfig cfg) {
    // Upstream olcrtc has no MTS-specific env knobs; keep pion quiet.
    final env = Map<String, String>.from(Platform.environment);
    env['PION_LOG_DISABLE'] = 'all';
    return env;
  }

  /// Builds an upstream-olcrtc `cnc` client YAML (schema: docs/configuration.md).
  /// Carriers are jitsi / telemost / wbstream; transports use the full
  /// `*channel` names. `data:` and (for video) `ffmpeg:` resolve next to
  /// olcrtc.exe inside [toolsDir].
  String _buildYaml(OlcConfig cfg, String toolsDir) {
    final dns = cfg.strParam('dns', _defaultDns);
    String yq(Object v) =>
        '"${v.toString().replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

    final out = StringBuffer()
      ..writeln('mode: cnc')
      ..writeln('auth:')
      ..writeln('  provider: ${yq(cfg.carrier)}')
      ..writeln('room:')
      ..writeln('  id: ${yq(cfg.roomId)}');
    // room.channel is optional peer-routing metadata; only emit a real one.
    if (cfg.clientId.isNotEmpty && cfg.clientId != 'default') {
      out.writeln('  channel: ${yq(cfg.clientId)}');
    }
    out
      ..writeln('crypto:')
      ..writeln('  key: ${yq(cfg.keyHex)}')
      ..writeln('net:')
      ..writeln('  transport: ${yq(cfg.transport)}')
      ..writeln('  dns: ${yq(dns)}')
      ..writeln('socks:')
      ..writeln('  host: ${yq(_socksHost)}')
      ..writeln('  port: $_socksPort')
      ..writeln('liveness:')
      ..writeln('  interval: ${yq(cfg.strParam('liveness-interval', '10s'))}')
      ..writeln('  timeout: ${yq(cfg.strParam('liveness-timeout', '5s'))}')
      ..writeln('  failures: ${cfg.intParam('liveness-failures', 3)}');

    switch (cfg.transport) {
      case Transport.vp8:
        out
          ..writeln('vp8:')
          ..writeln('  fps: ${cfg.intParam('vp8-fps', cfg.intParam('fps', 30))}')
          ..writeln('  batch_size: ${cfg.intParam('vp8-batch', cfg.intParam('batch', 8))}');
        break;
      case Transport.sei:
        out
          ..writeln('sei:')
          ..writeln('  fps: ${cfg.intParam('fps', cfg.intParam('sei-fps', 60))}')
          ..writeln('  batch_size: ${cfg.intParam('batch', cfg.intParam('sei-batch', 64))}')
          ..writeln('  fragment_size: ${cfg.intParam('frag', cfg.intParam('sei-frag', 900))}')
          ..writeln('  ack_timeout_ms: ${cfg.intParam('ack-ms', cfg.intParam('sei-ack-ms', 2000))}');
        break;
      case Transport.video:
        final codec = cfg.strParam('video-codec', 'qrcode');
        out
          ..writeln('video:')
          ..writeln('  codec: ${yq(codec)}')
          ..writeln('  width: ${cfg.intParam('video-w', cfg.intParam('video-width', 1080))}')
          ..writeln('  height: ${cfg.intParam('video-h', cfg.intParam('video-height', 1080))}')
          ..writeln('  fps: ${cfg.intParam('video-fps', 60)}')
          ..writeln('  bitrate: ${yq(cfg.strParam('video-bitrate', '5000k'))}')
          ..writeln('  hw: ${yq(cfg.strParam('video-hw', 'none'))}');
        if (codec == 'qrcode') {
          if (cfg.params.containsKey('video-qr-size')) {
            out.writeln('  qr_size: ${cfg.intParam('video-qr-size', 0)}');
          }
          if (cfg.params.containsKey('video-qr-recovery')) {
            out.writeln('  qr_recovery: ${yq(cfg.strParam('video-qr-recovery', 'medium'))}');
          }
        } else if (codec == 'tile') {
          if (cfg.params.containsKey('video-tile-module')) {
            out.writeln('  tile_module: ${cfg.intParam('video-tile-module', 0)}');
          }
          if (cfg.params.containsKey('video-tile-rs')) {
            out.writeln('  tile_rs: ${cfg.intParam('video-tile-rs', 0)}');
          }
        }
        // Branch fix/jitsi-nonblocking-connect: videochannel uses a pure-Go
        // codec — no external ffmpeg binary, so no `ffmpeg:` key.
        break;
    }
    out
      ..writeln('data: data')
      ..writeln('debug: false');
    return out.toString();
  }

  void _onCoreLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return;
    _harvestPeerIps(t);
    // Heuristic tagging
    String tag = 'LOG';
    if (t.contains('Link connected') || t.contains('ICE connected')) tag = 'OK';
    if (t.toLowerCase().contains('dns')) tag = 'DNS';
    if (t.toLowerCase().contains('tun2socks') || t.toLowerCase().contains('wintun')) tag = 'TUN';
    if (t.toLowerCase().contains('error') || t.toLowerCase().contains('failed')) tag = 'ERR';
    _addLog(tag, t);
  }

  /// Pull public IPv4s out of the core's ICE/candidate lines so full-tunnel
  /// mode can pin the carrier signaling server + TURN relays outside the
  /// tunnel. Restricted to ICE-ish lines to avoid pinning unrelated IPs.
  void _harvestPeerIps(String line) {
    final low = line.toLowerCase();
    final iceish = low.contains('[ice]') ||
        low.contains('candidate') ||
        low.contains('relay') ||
        low.contains('srflx') ||
        low.contains('prflx') ||
        low.contains('resolved');
    if (!iceish) return;
    for (final m in _ipRe.allMatches(line)) {
      final ip = m.group(1)!;
      if (_corePeerIps.add(ip) && _routeMode == 2 && _route.isRunning) {
        // New relay discovered after the tunnel came up — pin it immediately.
        unawaited(_route.addExclusion(ip));
      }
    }
  }

  void _onCoreExit(int code) {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _proc = null;
    _connectedAt = null;
    // Intentional shutdown: stop() owns the teardown + final state, and a
    // SIGTERM/kill exit code is not an error worth surfacing.
    if (_stopping) return;
    _addLog(code == 0 ? 'LOG' : 'ERR', 'core exited (code=$code)');
    _emit(TelemetrySnapshot.empty);
  }

  Future<bool> _waitForSocks(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_proc == null) return false;
      if (await _socksHandshake()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<bool> _socksHandshake() async {
    Socket? s;
    try {
      s = await Socket.connect(_socksHost, _socksPort,
              timeout: const Duration(seconds: 2));
      s.add([0x05, 0x01, 0x00]);
      final reply = await s.first.timeout(const Duration(seconds: 2));
      return reply.length >= 2 && reply[0] == 0x05 && reply[1] == 0x00;
    } catch (_) {
      return false;
    } finally {
      try {
        await s?.close();
      } catch (_) {}
    }
  }

  void _startTelemetryTimer() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_proc == null) return;
      // simple SOCKS probe RTT
      final start = DateTime.now();
      final ok = await _socksHandshake();
      _latency = ok ? DateTime.now().difference(start).inMilliseconds : -1;
      final uptime = _connectedAt == null
          ? Duration.zero
          : DateTime.now().difference(_connectedAt!);
      _emit(_last.copyWith(
        latencyMs: _latency,
        uptime: uptime,
      ));
    });
  }

  Future<String?> _resolveTool(String name) async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = <String>[
      p.join(exeDir, 'tools', name),
      p.join(exeDir, name),
      p.join(exeDir, 'data', 'flutter_assets', 'tools', name),
      // Dev fallback: canonical tools/ checked into windows/tools.
      p.normalize(p.join(exeDir, '..', '..', '..', '..', '..', 'windows', 'tools', name)),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  Future<String> _runtimeDir() async {
    final dir = await getApplicationSupportDirectory();
    final runtime = Directory(p.join(dir.path, 'runtime'));
    if (!await runtime.exists()) await runtime.create(recursive: true);
    return runtime.path;
  }

  void _addLog(String tag, String msg) {
    _events.add(LogEvent(ts: DateTime.now(), tag: tag, message: msg));
  }

  void _emit(TelemetrySnapshot s) {
    _last = s;
    _telemetry.add(s);
  }
}
