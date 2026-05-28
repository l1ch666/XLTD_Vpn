import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/connection_status.dart';

/// Manages the Windows full-tunnel routing setup:
///
/// 1. Brings up a Wintun-backed TUN adapter via `tun2socks.exe`.
/// 2. Adds a default route 0.0.0.0/0 through the TUN.
/// 3. Adds host-routes that *exclude* the VPN server and DNS upstream from
///    the tunnel so the SOCKS5 socket and the bootstrap DNS query never loop
///    back through their own tunnel.
/// 4. Restores the original routing table on stop.
///
/// This is the missing piece that made the Electron beta show "Full Tunnel
/// ACTIVE" but break browser traffic — the route table only ever had the
/// default route, so DNS resolution of the carrier hostname raced the
/// tunnel itself.
///
/// All `route.exe` and `netsh.exe` calls require **Administrator** rights.
/// `start()` throws [_AdminRequired] when invoked from an unelevated process
/// so the UI can surface a friendly prompt.
class WindowsRouteService {
  WindowsRouteService(this._addLog);

  final void Function(LogEvent) _addLog;

  Process? _tun2socks;
  String? _adapterName;
  final List<_RouteSnapshot> _addedRoutes = [];
  _DnsSnapshot? _dnsSnapshot;
  bool _running = false;

  static const _tunMtu = 1500;
  static const _adapterAlias = 'XltdTun';
  // Sentinel network used to push the TUN to the front of the routing
  // table (lower metric wins). Mirrors what the Android service does
  // with VpnService.Builder.addRoute("0.0.0.0", 1).
  static const _defaultRoutes = ['0.0.0.0/1', '128.0.0.0/1'];

  bool get isRunning => _running;

  /// Start full-tunnel mode. Resolves the carrier host, brings up tun2socks,
  /// adds the routes, sets DNS on the Wintun adapter.
  Future<void> start({
    required String socksHost,
    required int socksPort,
    required List<String> excludeHosts,
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

    // tun2socks brings up the adapter asynchronously — poll for up to 8 s.
    if (!await _waitForAdapter(_adapterAlias, const Duration(seconds: 8))) {
      throw StateError('Wintun adapter did not come up within 8s');
    }
    _log('TUN', 'wintun adapter "$_adapterAlias" up · mtu=$_tunMtu');

    // Add host-route exclusions BEFORE the default route so the upcoming
    // routing table doesn't blackhole the VPN socket and DNS bootstrap.
    final gw = await _defaultGateway();
    final iface = await _physicalInterfaceIndex();
    for (final host in excludeHosts) {
      for (final ip in await _resolveHost(host)) {
        await _addRoute(ip, '255.255.255.255', gw, iface);
      }
    }
    await _addRoute(dnsUpstream.split(':').first, '255.255.255.255', gw, iface);

    // Make the TUN the default route.
    final tunIfaceIdx = await _interfaceIndex(_adapterAlias);
    for (final cidr in _defaultRoutes) {
      final parts = cidr.split('/');
      final mask = _cidrToMask(int.parse(parts[1]));
      await _addRoute(parts[0], mask, '0.0.0.0', tunIfaceIdx);
    }

    // Lock DNS on the Wintun adapter to our pre-tunnel upstream so OS
    // resolvers don't leak queries via the physical interface.
    _dnsSnapshot = await _captureDns(_adapterAlias);
    await _setDns(_adapterAlias, dnsUpstream.split(':').first);

    _running = true;
    _log('OK', 'full tunnel up');
  }

  Future<void> stop() async {
    if (!_running && _tun2socks == null) return;
    _log('TUN', 'tearing down full tunnel');

    for (final r in _addedRoutes.reversed) {
      await _deleteRoute(r);
    }
    _addedRoutes.clear();

    if (_dnsSnapshot != null && _adapterName != null) {
      await _restoreDns(_adapterName!, _dnsSnapshot!);
      _dnsSnapshot = null;
    }

    try {
      _tun2socks?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    _tun2socks = null;
    _adapterName = null;
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
      p.normalize(p.join(exeDir, '..', '..', '..', '..',
          'windows', 'electron-app', 'tools', name)),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  Future<bool> _waitForAdapter(String name, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final r = await Process.run('netsh', ['interface', 'show', 'interface']);
      if (r.stdout.toString().contains(name)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
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

  Future<List<String>> _resolveHost(String hostOrIp) async {
    // Bypass our own DNS if hostOrIp is already an IP.
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(hostOrIp)) return [hostOrIp];
    try {
      final addrs = await InternetAddress.lookup(hostOrIp,
          type: InternetAddressType.IPv4);
      return addrs.map((a) => a.address).toSet().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addRoute(String dest, String mask, String gateway, String iface) async {
    final r = await Process.run('route', ['add', dest, 'MASK', mask, gateway, 'IF', iface, 'METRIC', '1']);
    if (r.exitCode == 0) {
      _addedRoutes.add(_RouteSnapshot(dest, mask));
      _log('TUN', 'route add $dest mask $mask via $gateway if=$iface');
    } else {
      _log('ERR', 'route add $dest failed: ${r.stderr}');
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
    if (r.exitCode != 0) _log('ERR', 'set dns: ${r.stderr}');
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
