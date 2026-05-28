/// A stored VPN profile (URI + UI metadata).
class Profile {
  final String id;
  final String link;        // raw olcrtc:// URI
  final String comment;     // user-friendly name (parsed from $... in URI)
  final String carrier;     // cached for list rendering
  final String transport;   // cached
  final DateTime? lastUsed;

  const Profile({
    required this.id,
    required this.link,
    required this.comment,
    required this.carrier,
    required this.transport,
    this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'link': link,
        'comment': comment,
        'carrier': carrier,
        'transport': transport,
        'lastUsed': lastUsed?.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        link: j['link'] as String,
        comment: (j['comment'] as String?) ?? '',
        carrier: (j['carrier'] as String?) ?? '',
        transport: (j['transport'] as String?) ?? '',
        lastUsed: j['lastUsed'] != null
            ? DateTime.tryParse(j['lastUsed'] as String)
            : null,
      );

  Profile copyWith({
    String? id,
    String? link,
    String? comment,
    String? carrier,
    String? transport,
    DateTime? lastUsed,
  }) =>
      Profile(
        id: id ?? this.id,
        link: link ?? this.link,
        comment: comment ?? this.comment,
        carrier: carrier ?? this.carrier,
        transport: transport ?? this.transport,
        lastUsed: lastUsed ?? this.lastUsed,
      );
}
