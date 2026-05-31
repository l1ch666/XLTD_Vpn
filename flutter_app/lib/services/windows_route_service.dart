import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/connection_status.dart';

/// Manages the Windows full-tunnel routing setup:
///
/// 1. Pins the core's own public peer IPs (carrier signaling server + TURN
///    relays) to the *physical* gateway so they bypass the tunnel. Without
///    this the core's own WebRTC/relay traffic gets captured by Wintun and
///    forwarded back into its own SOCKS proxy — the connection collapses and
///    the core exits (`use of closed network connection`, then a failed
///    re-bind on 127.0.0.1:10808).
/// 2. Brings up a Wintun-backed TUN adapter via `tun2socks.exe`, gives it an
///    IP, and points the default route (`0.0.0.0/1 + 128.0.0.0/1`) at it.
/// 3. Locks DNS on the TUN to the bootstrap upstream so resolvers don't leak.
/// 4. Restores routing + DNS on stop.
///
/// All `route.exe` / `netsh.exe` calls require **Administrator** rights.
/// `start()` throws [_AdminRequired] when invoked from an unelevated process
/// so the UI can surface a friendly prompt.
class WindowsRouteService {
  WindowsRouteService(this._addLog);

  final void Function(LogEvent) _addLog;

  Process? _tun2socks;
  String? _adapterName;
  final List<_RouteSnapshot> _addedRoutes = [];
  final Set<String> _excluded = <String>{};
  _DnsSnapshot? _dnsSnapshot;
  bool _running = false;

  // Cached physical egress, so peer IPs discovered *after* start (new relays)
  // can still be pinned outside the tunnel via [addExclusion].
  String? _gw;
  String? _physIface;

  static const _tunMtu = 1500;
  static const _adapterAlias = 'XltdTun';
  static const _tunAddr = '198.18.0.1';
  static const _tunMask = '255.255.255.0';
  // Two /1 routes beat the existing 0.0.0.0/0 default without deleting it,
  // mirroring VpnService.Builder.addRoute("0.0.0.0", 1) on Android.
  static const _defaultRoutes = ['0.0.0.0/1', '128.0.0.0/1'];

  bool get isRunning => _running;

  /// Start full-tunnel mode.
  ///
  /// [corePid] is the olcrtc.exe PID — its established TCP peers (the carrier
  /// signaling server) are pinned outside the tunnel. [peerIps] are extra
  /// public IPs already discovered from the core's ICE log (TURN relays).
  Future<void> start({
    required String socksHost,
    required int socksPort,
    required int corePid,
    required List<String> peerIps,
    required String dnsUpstream,
  }) async {
    if (_running) return;
    if (!await _isElevated()) {
      throw _AdminRequired();
    }
    final tun2socksExe = await _resolveTool('tun2socks.exe');
    final wintunDll = await _resolveTool('wintun.dll');
    if (tun2socksExe == null || wintunDll == null) {
      throw StateError('tun2socks.exe / wintun.dll missing — rebuild tools/');
    }
    // tun2socks must find wintun.dll next to it.
    final dllInPlace = p.join(p.dirname(tun2socksExe), 'wintun.dll');
    if (!await File(dllInPlace).exists() && wintunDll != dllInPlace) {
      try {
        await File(wintunDll).copy(dllInPlace);
      } catch (_) {/* fine, we already log + fail if missing */}
    }

    try {
      // 1) Pin the core's own endpoints to the physical gateway FIRST, before
      //    any TUN/default route exists, so flipping the default never
      //    blackholes the core's signaling/relay sockets.
      _gw = await _defaultGateway();
      _physIface = await _physicalInterfaceIndex();

      final dnsIp = dnsUpstream.split(':').first;
      final seed = <String>{...peerIps, dnsIp, ...await _tcpPeersByPid(corePid)};
      for (final ip in seed) {
        await addExclusion(ip);
      }
      _log('TUN', 'pinned ${_excluded.length} core endpoint(s) to physical gw');

      // 2) Bring up tun2socks + the Wintun adapter.
      _log('TUN', 'starting tun2socks · socks=$socksHost:$socksPort');
      _tun2socks = await Process.start(
        tun2socksExe,
        [
          '-device', 'wintun://$_adapterAlias',
          '-proxy', 'socks5://$socksHost:$socksPort',
          '-loglevel', 'info',
          '-mtu', '$_tunMtu',
        ],
        mode: ProcessStartMode.detachedWithStdio,
        runInShell: false,
      );
      _adapterName = _adapterAlias;

      if (!await _waitForAdapter(_adapterAlias, const Duration(seconds: 10))) {
        throw StateError('Wintun adapter did not come up within 10s');
      }
      _log('TUN', 'wintun adapter "$_adapterAlias" up · mtu=$_tunMtu');

      // 3) Give the TUN an address (tun2socks answers as the gateway) and make
      //    it the default route.
      await _setAdapterAddress(_adapterAlias, _tunAddr, _tunMask);
      final tunIfaceIdx = await _interfaceIndex(_adapterAlias);
      for (final cidr in _defaultRoutes) {
        final parts = cidr.split('/');
        final mask = _cidrToMask(int.parse(parts[1]));
        await _addRoute(parts[0], mask, _tunAddr, tunIfaceIdx);
      }

      // 4) Lock DNS on the TUN to our bootstrap upstream.
      _dnsSnapshot = await _captureDns(_adapterAlias);
      await _setDns(_adapterAlias, dnsIp);

      _running = true;
      _log('OK', 'full tunnel up');
    } catch (e) {
      // Never leave a half-applied routing table behind.
      _log('ERR', 'full tunnel start failed: $e — rolling back');
      await stop();
      rethrow;
    }
  }

  /// Pin a single public peer IP to the physical gateway (bypass the tunnel).
  /// Idempotent; safe to call repeatedly as new TURN relays appear.
  Future<void> addExclusion(String ip) async {
    ip = ip.trim();
    if (!_isExcludableIp(ip)) return;
    if (_excluded.contains(ip)) return;
    final gw = _gw;
    final iface = _physIface;
    if (gw == null || iface == null) return;
    _excluded.add(ip);
    await _addRoute(ip, '255.255.255.255', gw, iface);
  }

  Future<void> stop() async {
    if (!_running && _tun2socks == null && _addedRoutes.isEmpty) return;
    _log('TUN', 'tearing down full tunnel');

    for (final r in _addedRoutes.reversed) {
      await _deleteRoute(r);
    }
    _addedRoutes.clear();
    _excluded.clear();

    if (_dnsSnapshot != null && _adapterName != null) {
      await _restoreDns(_adapterName!, _dnsSnapshot!);
      _dnsSnapshot = null;
    }

    final proc = _tun2socks;
    _tun2socks = null;
    if (proc != null) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
      // Wait briefly so the adapter is released before any restart.
      try {
        await proc.exitCode.timeout(const Duration(seconds: 4));
      } catch (_) {
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
    _adapterName = null;
    _gw = null;
    _physIface = null;
    _running = false;
    _log('TUN', 'full tunnel stopped');
  }

  // ── helpers ───────────────────────────────────────────────────────────

  Future<bool> _isElevated() async {
    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-Command',
          '([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)'],
      );
      return r.stdout.toString().trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveTool(String name) async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = [
      p.join(exeDir, 'tools', name),
      p.join(exeDir, name),
      p.normalize(p.join(exeDir, '..', '..', '..', '..', '..',
          'windows', 'tools', name)),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  /// True for routable public IPv4 — i.e. an address we must keep OUTSIDE the
  /// tunnel. Private / loopback / link-local / multicast are left alone.
  bool _isExcludableIp(String ip) {
    final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(ip);
    if (m == null) return false;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    if (a > 255 || b > 255) return false;
    if (a == 0 || a == 10 || a == 127) return false;
    if (a == 169 && b == 254) return false;
    if (a == 172 && b >= 16 && b <= 31) return false;
    if (a == 192 && b == 168) return false;
    if (a >= 224) return false; // multicast / reserved
    return true;
  }

  /// Remote peers the core process currently has TCP connections to — the
  /// carrier signaling server (wss). UDP relays don't show a remote address
  /// here, so those come from the core's ICE log via [addExclusion].
  Future<List<String>> _tcpPeersByPid(int pid) async {
    try {
      final r = await Process.run('powershell', ['-NoProfile', '-Command',
        'Get-NetTCPConnection -OwningProcess $pid -ErrorAction SilentlyContinue | '
        'Select-Object -ExpandProperty RemoteAddress -Unique']);
      return r.stdout
          .toString()
          .split(RegExp(r'\s+'))
          .map((s) => s.trim())
          .where(_isExcludableIp)
          .toSet()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _waitForAdapter(String name, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      // tun2socks may have died immediately (bad DLL / SOCKS). Bail early.
      if (_tun2socks == null) return false;
      final r = await Process.run('netsh', ['interface', 'show', 'interface']);
      if (r.stdout.toString().contains(name)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  Future<void> _setAdapterAddress(String alias, String addr, String mask) async {
    final r = await Process.run('netsh', [
      'interface', 'ip', 'set', 'address',
      'name=$alias', 'static', addr, mask,
    ]);
    if (r.exitCode != 0) {
      _log('TUN', 'set tun address: ${r.stderr.toString().trim()}');
    }
  }

  Future<String> _defaultGateway() async {
    final r = await Process.run('powershell',
        ['-NoProfile', '-Command',
          '(Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).NextHop']);
    final out = r.stdout.toString().trim();
    if (out.isEmpty) {
      throw StateError('no default gateway found');
    }
    return out;
  }

  Future<String> _physicalInterfaceIndex() async {
    final r = await Process.run('powershell',
        ['-NoProfile', '-Command',
          '(Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).InterfaceIndex']);
    return r.stdout.toString().trim();
  }

  Future<String> _interfaceIndex(String alias) async {
    final r = await Process.run('powershell',
        ['-NoProfile', '-Command',
          '(Get-NetAdapter -Name "$alias").InterfaceIndex']);
    return r.stdout.toString().trim();
  }

  Future<void> _addRoute(String dest, String mask, String gateway, String iface) async {
    final r = await Process.run('route', ['add', dest, 'MASK', mask, gateway, 'IF', iface, 'METRIC', '1']);
    if (r.exitCode == 0) {
      _addedRoutes.add(_RouteSnapshot(dest, mask));
      _log('TUN', 'route add $dest mask $mask via $gateway if=$iface');
    } else {
      _log('ERR', 'route add $dest failed: ${r.stderr.toString().trim()}');
    }
  }

  Future<void> _deleteRoute(_RouteSnapshot r) async {
    await Process.run('route', ['delete', r.dest, 'MASK', r.mask]);
  }

  Future<_DnsSnapshot> _captureDns(String alias) async {
    final r = await Process.run('powershell',
        ['-NoProfile', '-Command',
          '(Get-DnsClientServerAddress -InterfaceAlias "$alias" -AddressFamily IPv4).ServerAddresses -join ","']);
    final servers = r.stdout
        .toString()
        .trim()
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
    return _DnsSnapshot(alias: alias, servers: servers);
  }

  Future<void> _setDns(String alias, String server) async {
    final r = await Process.run('netsh', [
      'interface', 'ipv4', 'set', 'dnsservers',
      'name=$alias', 'static', server, 'primary',
    ]);
    if (r.exitCode != 0) _log('ERR', 'set dns: ${r.stderr.toString().trim()}');
  }

  Future<void> _restoreDns(String alias, _DnsSnapshot snap) async {
    if (snap.servers.isEmpty) {
      await Process.run('netsh', ['interface', 'ipv4', 'set', 'dnsservers',
        'name=$alias', 'dhcp']);
    } else {
      await Process.run('netsh', ['interface', 'ipv4', 'set', 'dnsservers',
        'name=$alias', 'static', snap.servers.first, 'primary']);
    }
  }

  String _cidrToMask(int bits) {
    final m = 0xFFFFFFFF << (32 - bits);
    return '${(m >> 24) & 0xFF}.${(m >> 16) & 0xFF}.${(m >> 8) & 0xFF}.${m & 0xFF}';
  }

  void _log(String tag, String msg) {
    _addLog(LogEvent(ts: DateTime.now(), tag: tag, message: msg));
  }
}

class _RouteSnapshot {
  final String dest;
  final String mask;
  _RouteSnapshot(this.dest, this.mask);
}

class _DnsSnapshot {
  final String alias;
  final List<String> servers;
  _DnsSnapshot({required this.alias, required this.servers});
}

class _AdminRequired implements Exception {
  @override
  String toString() =>
      'Full-tunnel mode requires running XLTD VPN as Administrator.';
}
