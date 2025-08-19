import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

class DatabaseService {
  static final DatabaseService _i = DatabaseService._internal();
  factory DatabaseService() => _i;
  DatabaseService._internal();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<String> databasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'habits_timer.db');
  }

  Future<Database> _open() async {
    final path = await databasePath();
    final database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON;'),
      onCreate: (db, v) async {
        await db.execute('''CREATE TABLE activities(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, emoji TEXT, colorValue INTEGER NOT NULL,
          goalHoursPerWeek REAL DEFAULT 0, goalDaysPerWeek INTEGER DEFAULT 0, goalHoursPerDay REAL DEFAULT 0, createdAt TEXT NOT NULL);''');
        await db.execute('''CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          activityId INTEGER NOT NULL, startAt TEXT NOT NULL, endAt TEXT, note TEXT, tags TEXT,
          FOREIGN KEY(activityId) REFERENCES activities(id) ON DELETE CASCADE);''');
        await db.execute('''CREATE TABLE pauses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId INTEGER NOT NULL, startAt TEXT NOT NULL, endAt TEXT,
          FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE);''');
      },
    );
    return database;
  }

  // Activities
  Future<List<Activity>> getActivities() async {
    final d = await db;
    final rows = await d.query('activities', orderBy: "IFNULL(createdAt, '1970-01-01T00:00:00Z') DESC");
    return rows.map(Activity.fromMap).toList();
  }
  Future<int> insertActivity(Activity a) async {
    final d = await db; return d.insert('activities', a.toMap()..remove('id'));
  }
  Future<int> updateActivity(Activity a) async {
    final d = await db; return d.update('activities', a.toMap()..remove('createdAt'), where: 'id=?', whereArgs: [a.id]);
  }
  Future<int> deleteActivity(int id) async {
    final d = await db; return d.delete('activities', where: 'id=?', whereArgs: [id]);
  }

  // Sessions
  Future<Session?> getRunningSession(int activityId) async {
    final d = await db;
    final rows = await d.query('sessions', where: 'activityId=? AND endAt IS NULL', whereArgs: [activityId], orderBy: 'startAt DESC', limit: 1);
    if (rows.isEmpty) return null; return Session.fromMap(rows.first);
  }
  Future<int> startSession(int activityId, {String? note, List<String>? tags}) async {
    final d = await db;
    final running = await getRunningSession(activityId); if (running != null) await stopSession(running.id!);
    return d.insert('sessions', {'activityId': activityId, 'startAt': DateTime.now().toIso8601String(), 'note': note, 'tags': tags==null?null:jsonEncode(tags)});
  }
  Future<int> stopSession(int sessionId) async {
    final d = await db;
    await endPauseIfOpen(sessionId);
    return d.update('sessions', {'endAt': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [sessionId]);
  }
  Future<int> startPause(int sessionId) async {
    final d = await db;
    final open = await d.query('pauses', where: 'sessionId=? AND endAt IS NULL', whereArgs: [sessionId], limit: 1);
    if (open.isNotEmpty) return open.first['id'] as int;
    return d.insert('pauses', {'sessionId': sessionId, 'startAt': DateTime.now().toIso8601String()});
  }
  Future<void> endPauseIfOpen(int sessionId) async {
    final d = await db;
    final open = await d.query('pauses', where: 'sessionId=? AND endAt IS NULL', whereArgs: [sessionId], limit: 1);
    if (open.isNotEmpty) await d.update('pauses', {'endAt': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [open.first['id']]);
  }
  Future<int> endPause(int sessionId) async {
    final d = await db;
    final open = await d.query('pauses', where: 'sessionId=? AND endAt IS NULL', whereArgs: [sessionId], limit: 1);
    if (open.isEmpty) return 0;
    return d.update('pauses', {'endAt': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [open.first['id']]);
  }
  Future<bool> togglePause(int sessionId) async {
    final d = await db;
    final open = await d.query('pauses', where: 'sessionId=? AND endAt IS NULL', whereArgs: [sessionId], limit: 1);
    if (open.isNotEmpty) {
      await d.update('pauses', {'endAt': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [open.first['id']]);
      return false; // resumed
    } else {
      await d.insert('pauses', {'sessionId': sessionId, 'startAt': DateTime.now().toIso8601String()});
      return true; // paused
    }
  }

  Future<List<Session>> getSessionsBetween(DateTime start, DateTime end, {int? activityId}) async {
    final d = await db;
    final where = StringBuffer('startAt < ? AND (endAt IS NULL OR endAt > ?)');
    final args = <Object?>[end.toIso8601String(), start.toIso8601String()];
    if (activityId != null) { where.write(' AND activityId = ?'); args.add(activityId); }
    final rows = await d.query('sessions', where: where.toString(), whereArgs: args, orderBy: 'startAt ASC');
    return rows.map(Session.fromMap).toList();
  }

  Future<List<Pause>> getPausesForSession(int sessionId) async {
    final d = await db;
    final rows = await d.query('pauses', where: 'sessionId=?', whereArgs: [sessionId], orderBy: 'startAt ASC');
    return rows.map(Pause.fromMap).toList();
  }

  Future<Duration> activeDuration(Session s) async {
    final end = s.endAt ?? DateTime.now();
    var total = end.difference(s.startAt);
    final pauses = await getPausesForSession(s.id!);
    for (final p in pauses) {
      final pend = p.endAt ?? DateTime.now();
      final s1 = s.startAt.isAfter(p.startAt) ? s.startAt : p.startAt;
      final e1 = end.isBefore(pend) ? end : pend;
      if (e1.isAfter(s1)) total -= e1.difference(s1);
    }
    return total.isNegative ? Duration.zero : total;
  }

  Future<Map<DateTime, int>> dailyActiveMinutes(DateTime start, DateTime end, {int? activityId}) async {
    final sessions = await getSessionsBetween(start, end, activityId: activityId);
    final totals = <DateTime, int>{};
    DateTime dOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    Duration overlap(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
      final s = a1.isAfter(b1) ? a1 : b1; final e = a2.isBefore(b2) ? a2 : b2;
      if (!e.isAfter(s)) return Duration.zero; return e.difference(s);
    }
    final pausesById = <int, List<Pause>>{};
    for (final s in sessions) { pausesById[s.id!] = await getPausesForSession(s.id!); }
    for (final s in sessions) {
      final sEnd = s.endAt ?? DateTime.now();
      for (DateTime day = dOnly(s.startAt); !day.isAfter(dOnly(sEnd)); day = day.add(const Duration(days: 1))) {
        final dayStart = day; final dayEnd = day.add(const Duration(days: 1));
        final sessionOverlap = overlap(s.startAt, sEnd, dayStart, dayEnd); if (sessionOverlap == Duration.zero) continue;
        var active = sessionOverlap;
        for (final p in pausesById[s.id!] ?? const <Pause>[]) { active -= overlap(p.startAt, p.endAt ?? DateTime.now(), dayStart, dayEnd); }
        if (active.isNegative) continue;
        final m = active.inMinutes; totals.update(dayStart, (v) => v + m, ifAbsent: () => m);
      }
    }
    return totals;
  }

  DateTime mondayOnOrBefore(DateTime d){ final sub=(d.weekday+6)%7; return DateTime(d.year,d.month,d.day).subtract(Duration(days: sub)); }
  Future<int> minutesForDay(DateTime anyDay, int activityId) async {
    final start = DateTime(anyDay.year, anyDay.month, anyDay.day);
    final end = start.add(const Duration(days: 1));
    final map = await dailyActiveMinutes(start, end, activityId: activityId);
    return map[start] ?? 0;
  }
  Future<int> minutesForWeek(DateTime anyDay, int activityId) async {
    final monday = mondayOnOrBefore(anyDay); final sunday = monday.add(const Duration(days:7));
    final m = await dailyActiveMinutes(monday, sunday, activityId: activityId);
    return m.values.fold<int>(0, (a,b)=>a + b);
  }
  Future<int> activeDaysForWeek(DateTime anyDay, int activityId) async {
    final monday = mondayOnOrBefore(anyDay); final sunday = monday.add(const Duration(days:7));
    final m = await dailyActiveMinutes(monday, sunday, activityId: activityId);
    return m.values.where((v)=>v>0).length;
  }

  Future<List<int>> hourlyActiveMinutes(DateTime day, {int? activityId}) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sessions = await getSessionsBetween(start, end, activityId: activityId);
    final hours = List<int>.filled(24, 0);
    Duration overlap(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
      final s = a1.isAfter(b1) ? a1 : b1; final e = a2.isBefore(b2) ? a2 : b2;
      if (!e.isAfter(s)) return Duration.zero; return e.difference(s);
    }
    final pausesById = <int, List<Pause>>{};
    for (final s in sessions) { pausesById[s.id!] = await getPausesForSession(s.id!); }
    for (final s in sessions) {
      final sEnd = s.endAt ?? DateTime.now();
      for (int h=0; h<24; h++) {
        final hStart = start.add(Duration(hours: h));
        final hEnd = hStart.add(const Duration(hours: 1));
        final base = overlap(s.startAt, sEnd, hStart, hEnd);
        if (base == Duration.zero) continue;
        var active = base;
        for (final p in pausesById[s.id!] ?? const <Pause>[]) {
          active -= overlap(p.startAt, p.endAt ?? DateTime.now(), hStart, hEnd);
        }
        if (!active.isNegative) hours[h] += active.inMinutes;
      }
    }
    return hours;
  }

  Future<Map<String, Object?>> exportJson() async {
    final d = await db;
    final activities = (await d.query('activities'));
    final sessions = await d.query('sessions');
    final pauses = await d.query('pauses');
    return {'meta': {'exportedAt': DateTime.now().toIso8601String(), 'version': 1},
      'activities': activities, 'sessions': sessions, 'pauses': pauses};
  }

  Future<void> importJson(Map<String, Object?> data, {bool reset=false}) async {
    final d = await db; final batch = d.batch();
    if (reset) { batch.delete('pauses'); batch.delete('sessions'); batch.delete('activities'); }
    for (final a in (data['activities'] as List? ?? const [])) { batch.insert('activities', Map<String,Object?>.from(a as Map), conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final s in (data['sessions'] as List? ?? const [])) { batch.insert('sessions', Map<String,Object?>.from(s as Map), conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final p in (data['pauses'] as List? ?? const [])) { batch.insert('pauses', Map<String,Object?>.from(p as Map), conflictAlgorithm: ConflictAlgorithm.replace); }
    await batch.commit(noResult: true);
  }

  Future<void> resetDatabase() async { final d = await db; await d.delete('pauses'); await d.delete('sessions'); await d.delete('activities'); }
}
