import 'dart:async';

import 'package:flutter/services.dart';

import '../models/connection_status.dart';
import 'vpn_bridge.dart';

/// Android implementation. Talks to OlcVpnService over a single MethodChannel
/// (commands) and two EventChannels (telemetry + log lines).
///
/// The native side lives in `android/app/src/main/java/com/s1dechain/olcrtcvpn/`.
class AndroidVpnBridge implements VpnBridge {
  static const MethodChannel _ctl =
      MethodChannel('com.s1dechain.olcrtcvpn/control');
  static const EventChannel _telemetryCh =
      EventChannel('com.s1dechain.olcrtcvpn/telemetry');
  static const EventChannel _logCh =
      EventChannel('com.s1dechain.olcrtcvpn/log');

  final _telemetry = StreamController<TelemetrySnapshot>.broadcast();
  final _events = StreamController<LogEvent>.broadcast();
  TelemetrySnapshot _last = TelemetrySnapshot.empty;
  StreamSubscription<dynamic>? _telSub;
  StreamSubscription<dynamic>? _logSub;

  AndroidVpnBridge() {
    _wire();
  }

  void _wire() {
    _telSub = _telemetryCh.receiveBroadcastStream().listen((dynamic raw) {
      try {
        final m = Map<String, dynamic>.from(raw as Map);
        _last = _decode(m);
        _telemetry.add(_last);
      } catch (e) {
        // ignore malformed events
      }
    }, onError: (_) {});

    _logSub = _logCh.receiveBroadcastStream().listen((dynamic raw) {
      try {
        final m = Map<String, dynamic>.from(raw as Map);
        _events.add(LogEvent(
          ts: DateTime.fromMillisecondsSinceEpoch(
              (m['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
          tag: (m['tag'] as String?) ?? 'LOG',
          message: (m['msg'] as String?) ?? '',
        ));
      } catch (_) {}
    }, onError: (_) {});
  }

  TelemetrySnapshot _decode(Map<String, dynamic> m) {
    return TelemetrySnapshot(
      state: _state((m['state'] as String?) ?? 'disconnected'),
      carrier: m['carrier'] as String?,
      transport: m['transport'] as String?,
      rxBps: (m['rxBps'] as num?)?.toInt() ?? 0,
      txBps: (m['txBps'] as num?)?.toInt() ?? 0,
      sessionRxBytes: (m['sessionRx'] as num?)?.toInt() ?? 0,
      sessionTxBytes: (m['sessionTx'] as num?)?.toInt() ?? 0,
      latencyMs: (m['latencyMs'] as num?)?.toInt() ?? -1,
      uptime: Duration(milliseconds: (m['uptimeMs'] as num?)?.toInt() ?? 0),
      activeProfileId: m['profileId'] as String?,
      lastError: m['error'] as String?,
    );
  }

  VpnState _state(String s) {
    switch (s) {
      case 'connecting':
        return VpnState.connecting;
      case 'connected':
        return VpnState.connected;
      case 'reconnecting':
        return VpnState.reconnecting;
      case 'failed':
        return VpnState.failed;
      default:
        return VpnState.disconnected;
    }
  }

  @override
  Stream<TelemetrySnapshot> get telemetry async* {
    yield _last;
    yield* _telemetry.stream;
  }

  @override
  Stream<LogEvent> get events => _events.stream;

  @override
  Future<bool> healthCheck() async {
    try {
      final ok = await _ctl.invokeMethod<bool>('healthCheck');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start(String olcrtcUri) async {
    await _ctl.invokeMethod('start', {'uri': olcrtcUri});
  }

  @override
  Future<void> stop() async {
    await _ctl.invokeMethod('stop');
  }

  @override
  Future<int> getRouteMode() async => 2; // Android = always full tunnel

  @override
  Future<void> setRouteMode(int mode) async {
    // no-op on Android
  }

  void dispose() {
    _telSub?.cancel();
    _logSub?.cancel();
    _telemetry.close();
    _events.close();
  }
}
