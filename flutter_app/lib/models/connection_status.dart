/// Connection lifecycle states. Mirrors STATE_* in OlcVpnService.
enum VpnState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Live telemetry pushed from the VPN service / core process.
class TelemetrySnapshot {
  final VpnState state;
  final String? carrier;
  final String? transport;
  final int rxBps;           // bytes per second
  final int txBps;
  final int sessionRxBytes;
  final int sessionTxBytes;
  final int latencyMs;       // SOCKS probe RTT (negative = unknown)
  final Duration uptime;
  final String? activeProfileId;
  final String? lastError;

  const TelemetrySnapshot({
    this.state = VpnState.disconnected,
    this.carrier,
    this.transport,
    this.rxBps = 0,
    this.txBps = 0,
    this.sessionRxBytes = 0,
    this.sessionTxBytes = 0,
    this.latencyMs = -1,
    this.uptime = Duration.zero,
    this.activeProfileId,
    this.lastError,
  });

  TelemetrySnapshot copyWith({
    VpnState? state,
    String? carrier,
    String? transport,
    int? rxBps,
    int? txBps,
    int? sessionRxBytes,
    int? sessionTxBytes,
    int? latencyMs,
    Duration? uptime,
    String? activeProfileId,
    String? lastError,
  }) =>
      TelemetrySnapshot(
        state: state ?? this.state,
        carrier: carrier ?? this.carrier,
        transport: transport ?? this.transport,
        rxBps: rxBps ?? this.rxBps,
        txBps: txBps ?? this.txBps,
        sessionRxBytes: sessionRxBytes ?? this.sessionRxBytes,
        sessionTxBytes: sessionTxBytes ?? this.sessionTxBytes,
        latencyMs: latencyMs ?? this.latencyMs,
        uptime: uptime ?? this.uptime,
        activeProfileId: activeProfileId ?? this.activeProfileId,
        lastError: lastError ?? this.lastError,
      );

  static const TelemetrySnapshot empty = TelemetrySnapshot();
}

/// One line in the runtime log.
class LogEvent {
  final DateTime ts;
  final String tag; // OK, DNS, LOG, TUN, HINT, ERR
  final String message;

  const LogEvent({required this.ts, required this.tag, required this.message});
}
