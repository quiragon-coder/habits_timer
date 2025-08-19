import 'dart:convert';

class Session {
  final int? id;
  final int activityId;
  final DateTime startAt;
  final DateTime? endAt;
  final String? note;
  final List<String> tags;

  Session({
    this.id,
    required this.activityId,
    required this.startAt,
    this.endAt,
    this.note,
    List<String>? tags,
  }) : tags = tags ?? const [];

  Map<String, Object?> toMap() => {
        "id": id,
        "activityId": activityId,
        "startAt": startAt.toIso8601String(),
        "endAt": endAt?.toIso8601String(),
        "note": note,
        "tags": tags.isEmpty ? null : jsonEncode(tags),
      };

  static Session fromMap(Map<String, Object?> m) => Session(
        id: m["id"] as int?,
        activityId: (m["activityId"] as num).toInt(),
        startAt: DateTime.parse(m["startAt"] as String),
        endAt: (m["endAt"] as String?) != null ? DateTime.parse(m["endAt"] as String) : null,
        note: m["note"] as String?,
        tags: _decodeTags(m["tags"]),
      );

  static List<String> _decodeTags(Object? raw) {
    if (raw == null) return const [];
    if (raw is String) {
      try {
        final v = jsonDecode(raw);
        if (v is List) return v.map((e) => e.toString()).toList();
      } catch (_) {}
      return raw.split(',').map((e) => e.trim()).toList();
    }
    return const [];
  }
}
