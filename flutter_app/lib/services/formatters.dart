/// Pretty-print bytes, rates and durations for the UI.
///
/// Mirrors `formatBytes` / `formatRate` from MainActivity.java.

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  if (i == 0) return '${v.toInt()} ${units[i]}';
  return '${v.toStringAsFixed(v >= 100 ? 0 : (v >= 10 ? 1 : 2))} ${units[i]}';
}

/// Returns ("value", "unit"), e.g. ("12.4", "MB/s").
({String value, String unit}) splitRate(int bytesPerSec) {
  if (bytesPerSec <= 0) return (value: '0', unit: 'B/s');
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var v = bytesPerSec.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final asStr = i == 0
      ? v.toInt().toString()
      : v.toStringAsFixed(v >= 100 ? 0 : (v >= 10 ? 1 : 2));
  return (value: asStr, unit: units[i]);
}

String formatRate(int bytesPerSec) {
  final r = splitRate(bytesPerSec);
  return '${r.value} ${r.unit}';
}

String formatDuration(Duration d) {
  if (d.isNegative || d == Duration.zero) return '0:00';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatLatency(int ms) {
  if (ms < 0) return '—';
  return '$ms ms';
}

String formatHourMinute(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
