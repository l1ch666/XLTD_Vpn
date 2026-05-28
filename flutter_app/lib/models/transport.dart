/// Transport identifiers matching the Go core and olcrtc:// URI scheme.
class Transport {
  Transport._();

  static const String data  = 'datachannel';
  static const String vp8   = 'vp8channel';
  static const String sei   = 'seichannel';
  static const String video = 'videochannel';

  static const List<String> all = [sei, vp8, data, video];

  /// Short label for chips, badges and rail footer.
  static String label(String t) {
    switch (t) {
      case sei:   return 'SEI';
      case vp8:   return 'VP8';
      case data:  return 'Data';
      case video: return 'Video';
      default:    return t;
    }
  }

  /// Long label including transport-level params.
  /// Mirrors `activeTransportLabel()` from MainActivity / app.js.
  /// Single-channel SEI: just "SEI" (no lanes).
  static String longLabel(String t) {
    switch (t) {
      case sei:   return 'SEI';
      case vp8:   return 'VP8';
      case data:  return 'Data';
      case video: return 'Video';
      default:    return t;
    }
  }

  static bool isSupported(String t) {
    return t == data || t == vp8 || t == sei || t == video;
  }

  /// Normalise common aliases (`sei`, `dc`, `vp8`, etc.) to canonical names.
  static String normalize(String value) {
    final v = value.trim().toLowerCase();
    switch (v) {
      case 'data':
      case 'dc':
      case 'data_channel':
      case 'data-channel':
        return data;
      case 'vp8':
      case 'vp8_channel':
      case 'vp8-channel':
        return vp8;
      case 'sei':
      case 'sei_channel':
      case 'sei-channel':
        return sei;
      case 'video':
      case 'vid':
      case 'video_channel':
      case 'video-channel':
      case 'videochannel':
        return video;
      default:
        return v;
    }
  }
}
