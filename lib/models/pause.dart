class Pause {
  final int? id;
  final int sessionId;
  final DateTime startAt;
  final DateTime? endAt;

  Pause({this.id, required this.sessionId, required this.startAt, this.endAt});

  Map<String, Object?> toMap() => {
        "id": id,
        "sessionId": sessionId,
        "startAt": startAt.toIso8601String(),
        "endAt": endAt?.toIso8601String(),
      };

  static Pause fromMap(Map<String, Object?> m) => Pause(
        id: m["id"] as int?,
        sessionId: (m["sessionId"] as num).toInt(),
        startAt: DateTime.parse(m["startAt"] as String),
        endAt: (m["endAt"] as String?) != null ? DateTime.parse(m["endAt"] as String) : null,
      );
}
