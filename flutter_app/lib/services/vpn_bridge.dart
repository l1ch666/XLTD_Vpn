import 'dart:async';
import 'dart:io' show Platform;

import '../models/connection_status.dart';
import 'android_vpn_bridge.dart';
import 'windows_vpn_bridge.dart';

/// Platform-agnostic VPN backend interface.
///
/// Implementations:
///   * [AndroidVpnBridge] — talks to OlcVpnService over MethodChannel + EventChannel.
///   * [WindowsVpnBridge] — spawns olcrtc.exe (+ tun2socks.exe in full-tunnel mode).
abstract class VpnBridge {
  /// Stream of telemetry snapshots. Always emits the latest known state on listen.
  Stream<TelemetrySnapshot> get telemetry;

  /// Stream of runtime log lines from the core / VPN service.
  Stream<LogEvent> get events;

  /// True once the platform reports a healthy backend (Android: bound service;
  /// Windows: olcrtc.exe path resolved).
  Future<bool> healthCheck();

  /// Start the VPN. The bridge is responsible for prompting the OS-level
  /// permission flow on Android (VpnService.prepare) the first time.
  Future<void> start(String olcrtcUri);

  /// Stop the VPN cleanly.
  Future<void> stop();

  /// Route mode (Windows only — SOCKS-only / user-proxy / full-tunnel).
  /// Android always operates in full-tunnel mode via VpnService.
  Future<int> getRouteMode();
  Future<void> setRouteMode(int mode);
}

/// Lazy singleton — picks the right backend based on the current platform.
class Vpn {
  Vpn._();
  static VpnBridge? _instance;

  static VpnBridge get instance {
    _instance ??= _create();
    return _instance!;
  }

  static VpnBridge _create() {
    if (Platform.isAndroid) return AndroidVpnBridge();
    if (Platform.isWindows) return WindowsVpnBridge();
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

/// Default values used by Windows + Android telemetry plumbing.
class VpnConstants {
  VpnConstants._();
  static const int socksPort = 10808;
  static const String socksHost = '127.0.0.1';
}
