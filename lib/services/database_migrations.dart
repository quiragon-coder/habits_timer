import 'package:sqflite/sqflite.dart';

Future<void> applyMigrations(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
  final res = await db.rawQuery('PRAGMA user_version');
  final int currentVersion = (res.first['user_version'] as int?) ?? 0;

  if (currentVersion < 1) {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_activity ON sessions(activityId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_start ON sessions(startTime)');
    await db.execute('PRAGMA user_version = 1');
  }

  if (currentVersion < 2) {
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      try { await txn.execute('ALTER TABLE sessions RENAME TO sessions_old'); } catch (_) {}
      try { await txn.execute('ALTER TABLE pauses RENAME TO pauses_old'); } catch (_) {}

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          activityId INTEGER NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT,
          FOREIGN KEY(activityId) REFERENCES activities(id) ON DELETE CASCADE
        );
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS pauses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId INTEGER NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT,
          FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE
        );
      ''');

      try {
        await txn.execute('INSERT INTO sessions (id, activityId, startTime, endTime) SELECT id, activityId, startTime, endTime FROM sessions_old');
        await txn.execute('DROP TABLE sessions_old');
      } catch (_) {}
      try {
        await txn.execute('INSERT INTO pauses (id, sessionId, startTime, endTime) SELECT id, sessionId, startTime, endTime FROM pauses_old');
        await txn.execute('DROP TABLE pauses_old');
      } catch (_) {}

      await txn.execute('CREATE INDEX IF NOT EXISTS idx_sessions_activity ON sessions(activityId)');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_sessions_start ON sessions(startTime)');
      await txn.execute('PRAGMA foreign_keys = ON');
    });
    await db.execute('PRAGMA user_version = 2');
  }
}

