import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import 'uri_parser.dart';

/// Persists user-saved VPN profiles to local storage.
class ProfilesStore {
  static const String _key = 'xltd_profiles_v1';

  Future<List<Profile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <Profile>[];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      // Migrate: strip legacy multipath params from URIs saved before v1.10.
      return list.map((j) {
        final p = Profile.fromJson(j);
        final cleaned = UriParser.stripLegacyMultipath(p.link);
        return cleaned == p.link ? p : p.copyWith(link: cleaned);
      }).toList();
    } catch (_) {
      return <Profile>[];
    }
  }

  Future<void> save(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = <String>{};
    final ordered = <Profile>[];
    for (final p in profiles) {
      if (p.link.isEmpty || seen.contains(p.id)) continue;
      seen.add(p.id);
      ordered.add(p);
    }
    await prefs.setString(
      _key,
      jsonEncode(ordered.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> upsert(Profile profile) async {
    final list = await load();
    final idx = list.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }
    await save(list);
  }

  Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((p) => p.id == id);
    await save(list);
  }
}
