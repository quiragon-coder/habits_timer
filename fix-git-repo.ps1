Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "➡️  Vérification du dossier…"
if (-not (Test-Path "pubspec.yaml")) {
  Write-Host "❌ Ce dossier ne contient pas pubspec.yaml. Place-toi à la racine du projet Flutter."
  exit 1
}

Write-Host "➡️  Création du .gitignore…"
@"
# --- Flutter / Dart ---
.dart_tool/
.packages
.pub-cache/
build/
coverage/
ios/Flutter/Flutter.framework/
ios/Flutter/Flutter.podspec
ios/.symlinks/
ios/Pods/
macos/Pods/
windows/Flutter/ephemeral/
linux/flutter/ephemeral/
web/.dart_tool/

# --- Android / Gradle ---
android/.gradle/
android/.idea/
android/local.properties
android/app/release/
android/app/debug/
android/app/profile/
**/*.keystore
**/key.properties

# --- iOS / Xcode ---
**/DerivedData/
**/*.xcworkspace/
**/*.xcodeproj/project.xcworkspace/
**/*.xcodeproj/xcuserdata/
**/*.xcuserdatad/

# --- Firebase / Secrets ---
**/google-services.json
**/GoogleService-Info.plist
**/secrets*.json
**/.env
**/.env.*

# --- Données locales / exports ---
**/*.db
**/habits_timer.db
**/export_*.json

# --- IDE ---
.idea/
.vscode/
*.iml

# --- Autres ---
*.log
"@ | Out-File -FilePath .gitignore -Encoding UTF8 -NoNewline

if (-not (Test-Path ".git")) {
  Write-Host "➡️  Dépôt Git non initialisé : git init"
  git init | Out-Null
}

Write-Host "➡️  Nettoyage de l'index…"
# Vérifie si un commit existe
$hasHead = $false
try { git rev-parse --verify HEAD | Out-Null; $hasHead = $true } catch {}

if ($hasHead) {
  try { git rm -r --cached . | Out-Null } catch {}
}

Write-Host "➡️  Ajout des fichiers autorisés…"
git add .

# Commit uniquement s'il y a des changements en staging
$diff = git diff --cached --name-only
if (-not [string]::IsNullOrWhiteSpace($diff)) {
  git commit -m "chore: add Flutter .gitignore and clean repo" | Out-Null
} else {
  Write-Host "ℹ️  Rien à committer (déjà propre)."
}

$count = (& git ls-files | Measure-Object).Count
Write-Host "✅ Fichiers suivis par Git : $count"
Write-Host "👉 Tu devrais être dans l’ordre de quelques centaines (pas des centaines de milliers)."
Write-Host "➡️  Prochaine étape pour publier :"
Write-Host "   git branch -M main"
Write-Host "   git remote add origin https://github.com/<ton-user>/<habits_timer>.git"
Write-Host "   git push -u origin main"
