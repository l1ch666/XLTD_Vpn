import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/connection_status.dart';
import '../models/profile.dart';
import '../services/profiles_store.dart';
import '../services/uri_parser.dart';
import '../services/vpn_bridge.dart';

/// Single top-level app state container.
/// Exposed via Provider; UI widgets subscribe with `context.watch<AppState>()`.
class AppState extends ChangeNotifier {
  AppState(this._store, this._vpn) {
    _bootstrap();
  }

  final ProfilesStore _store;
  final VpnBridge _vpn;

  // ── public state ────────────────────────────────────────────────────
  List<Profile> profiles = const [];
  Profile? activeProfile;
  TelemetrySnapshot telemetry = TelemetrySnapshot.empty;
  int routeMode = 0; // 0=SOCKS, 1=user proxy, 2=full tunnel
  bool ready = false;

  final Queue<LogEvent> _eventLog = Queue<LogEvent>();
  static const int _maxEvents = 250;

  UnmodifiableListView<LogEvent> get events =>
      UnmodifiableListView(_eventLog);

  StreamSubscription<TelemetrySnapshot>? _telSub;
  StreamSubscription<LogEvent>? _evSub;

  Future<void> _bootstrap() async {
    profiles = await _store.load();
    if (profiles.isNotEmpty) activeProfile = profiles.first;
    routeMode = await _vpn.getRouteMode();
    _telSub = _vpn.telemetry.listen((t) {
      telemetry = t;
      notifyListeners();
    });
    _evSub = _vpn.events.listen((e) {
      _eventLog.addLast(e);
      while (_eventLog.length > _maxEvents) {
        _eventLog.removeFirst();
      }
      notifyListeners();
    });
    ready = true;
    notifyListeners();
  }

  // ── intents ─────────────────────────────────────────────────────────
  bool get isConnected => telemetry.state == VpnState.connected;
  bool get isBusy =>
      telemetry.state == VpnState.connecting ||
      telemetry.state == VpnState.reconnecting;

  Future<void> selectProfile(Profile p) async {
    activeProfile = p;
    notifyListeners();
  }

  Future<void> connect() async {
    final p = activeProfile;
    if (p == null) return;
    await _vpn.start(p.link);
  }

  Future<void> disconnect() async {
    await _vpn.stop();
  }

  /// Add or update a profile from a raw olcrtc:// link.
  /// Throws FormatException if invalid.
  Future<Profile> upsertFromLink(String rawLink, {String? id}) async {
    final cfg = UriParser.parse(rawLink);
    final cleaned = UriParser.stripLegacyMultipath(rawLink);
    final p = Profile(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      link: cleaned,
      comment: cfg.comment.isNotEmpty ? cfg.comment : '${cfg.carrier} · ${cfg.transport}',
      carrier: cfg.carrier,
      transport: cfg.transport,
    );
    await _store.upsert(p);
    profiles = await _store.load();
    activeProfile = profiles.firstWhere(
      (e) => e.id == p.id,
      orElse: () => p,
    );
    notifyListeners();
    return p;
  }

  Future<void> deleteProfile(String id) async {
    await _store.delete(id);
    profiles = await _store.load();
    if (activeProfile?.id == id) {
      activeProfile = profiles.isEmpty ? null : profiles.first;
    }
    notifyListeners();
  }

  Future<void> setRouteMode(int mode) async {
    routeMode = mode;
    await _vpn.setRouteMode(mode);
    notifyListeners();
  }

  /// Replace the active profile's transport via a new URI.
  /// Used by transport chips.
  Future<void> switchTransport(String newTransport) async {
    final p = activeProfile;
    if (p == null) return;
    // crude substitution in the URI: replace the first transport token between `?` and `<`/`@`.
    final reg = RegExp(r'(\?)(.+?)([<@])');
    final m = reg.firstMatch(p.link);
    if (m == null) return;
    final body = m.group(2)!;
    final brk = body.indexOf('<');
    final rest = brk >= 0 ? body.substring(brk) : '';
    final newBody = '${m.group(1)}$newTransport$rest${m.group(3)}';
    final newLink = p.link.replaceFirst(reg, newBody);
    await upsertFromLink(newLink, id: p.id);
    if (isConnected) {
      await disconnect();
      await connect();
    }
  }

  @override
  void dispose() {
    _telSub?.cancel();
    _evSub?.cancel();
    super.dispose();
  }
}
