/// Parsed olcrtc:// URI. Immutable.
///
/// Mirrors `OlcConfig` (Java) and the object returned by `parser.js`.
class OlcConfig {
  final String carrier;
  final String transport;
  final String roomId;
  final String keyHex;
  final String clientId;
  final String comment;
  final Map<String, String> params;

  const OlcConfig({
    required this.carrier,
    required this.transport,
    required this.roomId,
    required this.keyHex,
    required this.clientId,
    required this.comment,
    required this.params,
  });

  /// Read an int param with a default fallback.
  int intParam(String key, int def) {
    final v = params[key];
    if (v == null) return def;
    return int.tryParse(v) ?? def;
  }

  /// Read a string param with a default fallback.
  String strParam(String key, String def) {
    final v = params[key];
    return (v == null || v.isEmpty) ? def : v;
  }

  bool get isMtsLink => carrier == 'mtslink';
}
