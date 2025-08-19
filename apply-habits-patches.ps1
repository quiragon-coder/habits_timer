Param(
  [string]$ProjectPath = "."
)
$ErrorActionPreference = "Stop"

function Info($m){ Write-Host "[INFO] $m" }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Ok($m){ Write-Host "[OK]   $m" -ForegroundColor Green }

Set-Location $ProjectPath
if (-not (Test-Path "pubspec.yaml")) { throw "Ce dossier ne contient pas pubspec.yaml. Place-toi a la racine du projet." }

New-Item -ItemType Directory -Force -Path "lib\services" | Out-Null
New-Item -ItemType Directory -Force -Path ".github\workflows" | Out-Null

$migPath = "lib\services\database_migrations.dart"
@'
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

'@ | Out-File -FilePath $migPath -Encoding UTF8
Ok "Ecrit: $migPath"

$ciPath = ".github\workflows\flutter_ci.yml"
@'
name: Flutter CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
          cache: true

      - name: Flutter pub get
        run: flutter pub get

      - name: Format check
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze

      - name: Unit tests (with coverage)
        run: flutter test --coverage

      - name: Build debug APK (sanity)
        run: flutter build apk --debug

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-outputs
          path: |
            build/app/outputs/**/*.apk
            coverage/lcov.info

'@ | Out-File -FilePath $ciPath -Encoding UTF8
Ok "Ecrit: $ciPath"

$anaPath = "analysis_options.yaml"
if (-not (Test-Path $anaPath)) {
@'
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_final_locals: true
    always_declare_return_types: true
    avoid_print: true
    unnecessary_late: true
    use_key_in_widget_constructors: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    directives_ordering: true
    sort_pub_dependencies: false

'@ | Out-File -FilePath $anaPath -Encoding UTF8
Ok "Ecrit: $anaPath"
} else {
Warn "$anaPath existe deja, je ne l ecrase pas."
}

$dbFile = "lib\services\database_service.dart"
if (Test-Path $dbFile) {
  Info "Patching $dbFile"
  Copy-Item $dbFile "$dbFile.bak" -Force
  $c = Get-Content $dbFile -Raw

  if ($c -notmatch "database_migrations\.dart") {
    $c = $c -replace "(?ms)(^import .+?;\s*)(?!.*^import )", "${0}import 'database_migrations.dart';`r`n"
  }
  if ($c -notmatch "onConfigure\s*:") {
    $c = $c -replace "(openDatabase\()", "`$1 onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); }, "
  }
  if ($c -notmatch "applyMigrations\s*\(") {
    if ($c -notmatch "onOpen\s*:") {
      $c = $c -replace "(openDatabase\()", "`$1 onOpen: (db) async { await applyMigrations(db); }, "
    }
  }

  Set-Content -Path $dbFile -Value $c -Encoding UTF8
  Ok "Patch applique (backup: $dbFile.bak)"
} else {
  Warn "$dbFile introuvable. Ajoute manuellement: import 'database_migrations.dart'; et les callbacks onConfigure/onOpen."
}

if (Test-Path ".git") {
  try {
    git add "$migPath" 2>$null
    git add "$ciPath" 2>$null
    if (Test-Path $anaPath) { git add "$anaPath" 2>$null }
    if (Test-Path $dbFile) { git add "$dbFile" 2>$null }
    git commit -m "chore(db): add migrations (FK cascade + indexes) and CI" | Out-Null
    try { git push | Out-Null } catch { Warn "push a echoue (remote non configure)." }
    Ok "Commit effectue."
  } catch {
    Warn "Rien a committer ou Git non configure."
  }
} else {
  Warn "Pas de depot Git detecte."
}

Ok "Termine."
