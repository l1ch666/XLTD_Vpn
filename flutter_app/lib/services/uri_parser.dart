import '../models/olc_config.dart';
import '../models/transport.dart';

/// Parser for olcrtc://... universal-carrier URIs.
///
/// Behaviour matches Java's `OlcUriParser` and Electron's `parser.js`:
///
///   olcrtc://<carrier>?<transport>[<key=value&...>]@<roomId>#<keyHex>[%clientId][$comment]
///
/// Legacy `%clientId` tails are still accepted. Copied server output blocks
/// containing a `uri: olcrtc://...` prefix line are accepted too.
class UriParser {
  UriParser._();

  static const String _scheme = 'olcrtc://';

  static OlcConfig parse(String raw) {
    if (raw.trim().isEmpty) throw FormatException('empty link');
    final value = _extractUri(raw);
    if (!value.toLowerCase().startsWith(_scheme)) {
      throw FormatException('link must start with olcrtc://');
    }

    final body = value.substring(_scheme.length);
    final q = body.indexOf('?');
    final at = q >= 0 ? body.indexOf('@', q + 1) : -1;
    final hash = at >= 0 ? body.indexOf('#', at + 1) : -1;

    if (q <= 0) throw FormatException('missing carrier or ?');
    if (at <= q) throw FormatException('missing transport or @');
    if (hash <= at) throw FormatException('missing roomId or #');

    final carrier = _decode(body.substring(0, q)).trim().toLowerCase();
    final spec = body.substring(q + 1, at).trim();
    final transportSpec = _parseTransportSpec(spec);
    final transport = Transport.normalize(transportSpec.transport);
    if (!Transport.isSupported(transport)) {
      throw FormatException(
          'unsupported transport: use datachannel, vp8channel, seichannel or videochannel');
    }

    final roomId = _decode(body.substring(at + 1, hash)).trim();
    final tail = _parseTail(body.substring(hash + 1));
    var clientId = tail.clientId.trim();
    if (clientId.isEmpty) {
      clientId = (transportSpec.params['client-id'] ??
              transportSpec.params['clientid'] ??
              transportSpec.params['client'] ??
              'default')
          .trim();
      if (clientId.isEmpty) clientId = 'default';
    }

    if (carrier.isEmpty) throw FormatException('carrier is empty');
    if (transport.isEmpty) throw FormatException('transport is empty');
    if (roomId.isEmpty && carrier != 'jazz') {
      throw FormatException('roomId is empty');
    }
    if (tail.keyHex.length != 64) {
      throw FormatException('keyHex must be 64 hex chars');
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(tail.keyHex)) {
      throw FormatException('keyHex is not hex');
    }

    return OlcConfig(
      carrier: carrier,
      transport: transport,
      roomId: roomId,
      keyHex: tail.keyHex,
      clientId: clientId,
      comment: tail.comment,
      params: transportSpec.params,
    );
  }

  /// Strip multipath / traffic params from a raw URI string for migration of
  /// pre-1.10 saved profiles. The URI may stay otherwise unchanged.
  static String stripLegacyMultipath(String raw) {
    final lower = raw.toLowerCase();
    final open = lower.indexOf('<');
    if (open < 0) return raw;
    final close = lower.lastIndexOf('>');
    if (close <= open) return raw;
    final inside = raw.substring(open + 1, close);
    final keep = inside
        .split('&')
        .where((p) {
          final eq = p.indexOf('=');
          final k = (eq >= 0 ? p.substring(0, eq) : p).toLowerCase().trim();
          if (k.startsWith('mc-')) return false;
          if (k.startsWith('traffic-')) return false;
          return true;
        })
        .join('&');
    return '${raw.substring(0, open + 1)}$keep${raw.substring(close)}';
  }

  // ── internals ──────────────────────────────────────────────────────────

  static String _extractUri(String raw) {
    final s = raw.trim();
    final lower = s.toLowerCase();
    final start = lower.indexOf(_scheme);
    if (start < 0) return s;
    final sub = s.substring(start).trim();
    final crLf = RegExp(r'[\r\n]');
    final m = crLf.firstMatch(sub);
    return m == null ? sub : sub.substring(0, m.start).trim();
  }

  static _TransportSpec _parseTransportSpec(String spec) {
    if (spec.isEmpty) throw FormatException('transport is empty');
    final open = spec.indexOf('<');
    if (open < 0) return _TransportSpec(spec, const {});
    final close = spec.lastIndexOf('>');
    if (close < open || close != spec.length - 1) {
      throw FormatException('bad transport params: expected transport<key=value&...>');
    }
    final transport = spec.substring(0, open).trim();
    final inside = spec.substring(open + 1, close).trim();
    return _TransportSpec(transport, _parseParams(inside));
  }

  static Map<String, String> _parseParams(String raw) {
    final out = <String, String>{};
    if (raw.isEmpty) return out;
    for (final pair in raw.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final k =
          _decode(eq >= 0 ? pair.substring(0, eq) : pair).trim().toLowerCase();
      final v = eq >= 0 ? _decode(pair.substring(eq + 1)).trim() : '';
      if (k.isNotEmpty) out[k] = v;
    }
    return out;
  }

  static _TailParts _parseTail(String rawTail) {
    if (rawTail.isEmpty) throw FormatException('missing keyHex');
    final percent = rawTail.indexOf('%');
    final dollar = rawTail.indexOf('\$');
    String key, client = '', comment = '';

    if (percent >= 0 && (dollar < 0 || percent < dollar)) {
      key = rawTail.substring(0, percent);
      if (dollar > percent) {
        client = rawTail.substring(percent + 1, dollar);
        comment = rawTail.substring(dollar + 1);
      } else {
        client = rawTail.substring(percent + 1);
      }
    } else if (dollar >= 0) {
      key = rawTail.substring(0, dollar);
      comment = rawTail.substring(dollar + 1);
    } else {
      key = rawTail;
    }
    return _TailParts(
      keyHex: _decode(key),
      clientId: _decode(client),
      comment: _decode(comment),
    );
  }

  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }
}

class _TransportSpec {
  final String transport;
  final Map<String, String> params;
  _TransportSpec(this.transport, this.params);
}

class _TailParts {
  final String keyHex;
  final String clientId;
  final String comment;
  _TailParts({required this.keyHex, required this.clientId, required this.comment});
}
