// lib/services/database_service.dart
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

import 'database_migrations.dart';

class DatabaseService {
  DatabaseService(); // <- constructeur par défaut attendu par providers.dart

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  /// Retourne le chemin du fichier DB (utilisé par Settings).
  Future<String> databasePath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'habits_timer.db');
  }

  Future<Database> _openDb() async {
    final path = await databasePath();

    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // NOTE: si ton schéma d'activités contient d'autres colonnes (objectifs…),
        // ajoute-les ici pour rester en phase avec tes modèles.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS activities(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activityId INTEGER NOT NULL,
            startAt TEXT NOT NULL,
            endAt TEXT,
            FOREIGN KEY(activityId) REFERENCES activities(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS pauses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId INTEGER NOT NULL,
            startAt TEXT NOT NULL,
            endAt TEXT,
            FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE
          );
        ''');
      },
      onOpen: (db) async {
        await applyMigrations(db); // indexes + FK cascade idempotents
      },
    );

    return db;
  }

  // ────────────────────────────────
  // Activities
  // ────────────────────────────────

  Future<int> insertActivity(Activity a) async {
    final db = await database;
    return db.insert(
      'activities',
      a.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateActivity(Activity a) async {
    final db = await database;
    return db.update(
      'activities',
      a.toMap(),
      where: 'id = ?',
      whereArgs: [a.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Activity>> getActivities() async {
    final db = await database;
    final rows = await db.query('activities', orderBy: 'id DESC');
    return rows.map((m) => Activity.fromMap(m)).toList();
  }

  Future<int> deleteActivity(int activityId) async {
    final db = await database;
    return db.delete('activities', where: 'id = ?', whereArgs: [activityId]);
  }

  // ────────────────────────────────
  // Sessions
  // ────────────────────────────────

  Future<int> startSession(int activityId) async {
    final db = await database;

    // évite deux sessions ouvertes pour la même activité
    final existing = await db.query(
      'sessions',
      where: 'activityId = ? AND endAt IS NULL',
      whereArgs: [activityId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    final now = DateTime.now().toIso8601String();
    return db.insert(
      'sessions',
      {'activityId': activityId, 'startAt': now, 'endAt': null},
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> stopSession({int? activityId, int? sessionId}) async {
    final db = await database;

    Map<String, Object?>? row;
    if (sessionId != null) {
      final r = await db.query('sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
      if (r.isNotEmpty) row = r.first;
    } else if (activityId != null) {
      final r = await db.query(
        'sessions',
        where: 'activityId = ? AND endAt IS NULL',
        whereArgs: [activityId],
        limit: 1,
      );
      if (r.isNotEmpty) row = r.first;
    }
    if (row == null) return 0;

    final id = row['id'] as int;
    final now = DateTime.now().toIso8601String();
    return db.update('sessions', {'endAt': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Session?> getRunningSession([int? activityId]) async {
    final db = await database;
    final where = StringBuffer('endAt IS NULL');
    final args = <Object?>[];
    if (activityId != null) {
      where.write(' AND activityId = ?');
      args.add(activityId);
    }
    final r = await db.query('sessions', where: where.toString(), whereArgs: args, limit: 1);
    if (r.isEmpty) return null;
    return Session.fromMap(r.first);
  }

  Future<void> togglePause({int? activityId, int? sessionId}) async {
    final db = await database;

    Session? s;
    if (sessionId != null) {
      final r = await db.query('sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
      if (r.isNotEmpty) s = Session.fromMap(r.first);
    } else if (activityId != null) {
      final r = await db.query(
        'sessions',
        where: 'activityId = ? AND endAt IS NULL',
        whereArgs: [activityId],
        limit: 1,
      );
      if (r.isNotEmpty) s = Session.fromMap(r.first);
    }
    if (s == null) return;

    final open = await getOpenPauseForSession(s.id!);
    final now = DateTime.now().toIso8601String();

    if (open != null) {
      await _updatePauseEnd(open.id!, now);
    } else {
      await _insertPause(Pause(id: null, sessionId: s.id!, startAt: DateTime.now(), endAt: null));
    }
  }

  Future<List<Session>> getSessionsBetween(DateTime from, DateTime to, {int? activityId}) async {
    final db = await database;
    final f = from.toIso8601String();
    final t = to.toIso8601String();

    final where = StringBuffer('startAt <= ? AND (endAt IS NULL OR endAt >= ?)');
    final args = <Object?>[t, f];

    if (activityId != null) {
      where.write(' AND activityId = ?');
      args.add(activityId);
    }

    final rows = await db.query('sessions', where: where.toString(), whereArgs: args, orderBy: 'startAt ASC');
    return rows.map(Session.fromMap).toList();
  }

  // ────────────────────────────────
  // Pauses
  // ────────────────────────────────

  Future<Pause?> getOpenPauseForSession(int sessionId) async {
    final db = await database;
    final r = await db.query(
      'pauses',
      where: 'sessionId = ? AND endAt IS NULL',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return Pause.fromMap(r.first);
  }

  Future<List<Pause>> getPausesForSession(int sessionId) async {
    final db = await database;
    final rows = await db.query('pauses', where: 'sessionId = ?', whereArgs: [sessionId], orderBy: 'startAt ASC');
    return rows.map(Pause.fromMap).toList();
  }

  Future<int> _insertPause(Pause pz) async {
    final db = await database;
    return db.insert('pauses', pz.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> _updatePauseEnd(int id, String endIso) async {
    final db = await database;
    return db.update('pauses', {'endAt': endIso}, where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────────────
  // Stats & agrégations
  // ────────────────────────────────

  /// Minutes actives sur un **jour** (minuit→minuit), pauses déduites.
  Future<int> minutesForDay(DateTime day, [int? activityId]) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final ms = await _activeMillisInRange(start, end, activityId: activityId);
    return ms ~/ 60000;
  }

  /// Retourne le **nombre de jours actifs** (>= 1 minute) pour la semaine du lundi [monday].
  Future<int> activeDaysForWeek(DateTime monday, [int? activityId]) async {
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      final mins = await minutesForDay(d, activityId);
      if (mins > 0) count++;
    }
    return count;
  }

  /// Minutes actives **par heure** pour un jour donné (length = 24).
  Future<List<int>> hourlyActiveMinutes(DateTime day, [int? activityId]) async {
    final start = DateTime(day.year, day.month, day.day);
    final result = List<int>.filled(24, 0);

    // Fenêtre d’un jour
    final dayEnd = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final sessions = await getSessionsBetween(start, dayEnd, activityId: activityId);

    for (final s in sessions) {
      final sStart = s.startAt;
      final sEnd = s.endAt ?? DateTime.now();

      var from = sStart.isBefore(start) ? start : sStart;
      var to = sEnd.isAfter(dayEnd) ? dayEnd : sEnd;
      if (!to.isAfter(from)) continue;

      // Déduire les pauses
      final pauses = await getPausesForSession(s.id!);
      final intervals = <(DateTime, DateTime)>[(from, to)];
      for (final pz in pauses) {
        final pS = pz.startAt;
        final pE = pz.endAt ?? DateTime.now();
        final cutS = pS.isBefore(from) ? from : pS;
        final cutE = pE.isAfter(to) ? to : pE;
        if (cutE.isAfter(cutS)) {
          // on coupe l'intervalle actif
          final newIntervals = <(DateTime, DateTime)>[];
          for (final (a, b) in intervals) {
            if (cutE.isBefore(a) || cutS.isAfter(b)) {
              newIntervals.add((a, b));
            } else {
              if (cutS.isAfter(a)) newIntervals.add((a, cutS));
              if (cutE.isBefore(b)) newIntervals.add((cutE, b));
            }
          }
          intervals
            ..clear()
            ..addAll(newIntervals);
        }
      }

      for (final (a, b) in intervals) {
        var cursor = a;
        while (cursor.isBefore(b)) {
          final hourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour).add(const Duration(hours: 1));
          final segEnd = b.isBefore(hourEnd) ? b : hourEnd;
          final minutes = (segEnd.millisecondsSinceEpoch - cursor.millisecondsSinceEpoch) ~/ 60000;
          result[cursor.hour] += minutes;
          cursor = segEnd;
        }
      }
    }

    return result;
  }

  /// Durée active réelle d'une session (pauses soustraites).
  Future<Duration> activeDuration(Session s) async {
    final start = s.startAt;
    final end = s.endAt ?? DateTime.now();
    var ms = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;

    final pauses = await getPausesForSession(s.id!);
    for (final pz in pauses) {
      final pS = pz.startAt;
      final pE = pz.endAt ?? DateTime.now();
      final a = pS.isBefore(start) ? start : pS;
      final b = pE.isAfter(end) ? end : pE;
      if (b.isAfter(a)) {
        ms -= (b.millisecondsSinceEpoch - a.millisecondsSinceEpoch);
      }
    }
    if (ms < 0) ms = 0;
    return Duration(milliseconds: ms);
  }

  Future<int> minutesForWeek(DateTime monday, {int? activityId}) async {
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
    final ms = await _activeMillisInRange(start, end, activityId: activityId);
    return ms ~/ 60000;
  }

  Future<int> _activeMillisInRange(DateTime rangeStart, DateTime rangeEnd, {int? activityId}) async {
    final sessions = await getSessionsBetween(rangeStart, rangeEnd, activityId: activityId);
    int total = 0;

    for (final s in sessions) {
      var a = s.startAt.isBefore(rangeStart) ? rangeStart : s.startAt;
      var b = (s.endAt ?? DateTime.now()).isAfter(rangeEnd) ? rangeEnd : (s.endAt ?? DateTime.now());
      if (!b.isAfter(a)) continue;

      var activeMs = b.millisecondsSinceEpoch - a.millisecondsSinceEpoch;

      final pauses = await getPausesForSession(s.id!);
      for (final pz in pauses) {
        final pS = pz.startAt.isBefore(a) ? a : pz.startAt;
        final pE = (pz.endAt ?? DateTime.now()).isAfter(b) ? b : (pz.endAt ?? DateTime.now());
        if (pE.isAfter(pS)) {
          activeMs -= (pE.millisecondsSinceEpoch - pS.millisecondsSinceEpoch);
        }
      }

      if (activeMs > 0) total += activeMs;
    }

    return total;
  }

  // ────────────────────────────────
  // Export / Import / Reset
  // ────────────────────────────────

  Future<String> exportJson() async {
    final db = await database;
    final activities = await db.query('activities');
    final sessions = await db.query('sessions');
    final pauses = await db.query('pauses');

    final data = {
      'meta': {'exportedAt': DateTime.now().toIso8601String(), 'version': 1},
      'activities': activities,
      'sessions': sessions,
      'pauses': pauses,
    };
    return jsonEncode(data);
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('pauses');
      await txn.delete('sessions');
      await txn.delete('activities');
    });
  }

  Future<void> importJson(String json, {bool resetFirst = false}) async {
    final db = await database;
    final map = jsonDecode(json) as Map<String, dynamic>;
    final activities = (map['activities'] as List).cast<Map>().cast<Map<String, dynamic>>();
    final sessions = (map['sessions'] as List).cast<Map>().cast<Map<String, dynamic>>();
    final pauses = (map['pauses'] as List).cast<Map>().cast<Map<String, dynamic>>();

    await db.transaction((txn) async {
      if (resetFirst) {
        await txn.delete('pauses');
        await txn.delete('sessions');
        await txn.delete('activities');
      }

      for (final a in activities) {
        await txn.insert('activities', a, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final s in sessions) {
        await txn.insert('sessions', s, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final pz in pauses) {
        await txn.insert('pauses', pz, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
