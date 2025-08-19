class Activity {
  final int? id;
  final String name;
  final String emoji;
  final int colorValue;
  final double goalHoursPerWeek;
  final double goalHoursPerDay;
  final int goalDaysPerWeek;
  final DateTime createdAt;

  Activity({
    this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.goalHoursPerWeek = 0,
    this.goalHoursPerDay = 0,
    this.goalDaysPerWeek = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        "id": id,
        "name": name,
        "emoji": emoji,
        "colorValue": colorValue,
        "goalHoursPerWeek": goalHoursPerWeek,
        "goalHoursPerDay": goalHoursPerDay,
        "goalDaysPerWeek": goalDaysPerWeek,
        "createdAt": createdAt.toIso8601String(),
      };

  static Activity fromMap(Map<String, Object?> m) => Activity(
        id: m["id"] as int?,
        name: (m["name"] as String?) ?? "",
        emoji: (m["emoji"] as String?) ?? "⏱️",
        colorValue: (m["colorValue"] as int?) ?? 0xFF6750A4,
        goalHoursPerWeek: (m["goalHoursPerWeek"] as num?)?.toDouble() ?? 0.0,
        goalHoursPerDay: (m["goalHoursPerDay"] as num?)?.toDouble() ?? 0.0,
        goalDaysPerWeek: (m["goalDaysPerWeek"] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((m["createdAt"] as String?) ?? "") ?? DateTime.now(),
      );
}
