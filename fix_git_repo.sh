#!/usr/bin/env bash
set -euo pipefail

echo "➡️  Vérification du dossier…"
if [[ ! -f "pubspec.yaml" ]]; then
  echo "❌ Ce dossier ne contient pas pubspec.yaml. Place-toi à la racine du projet Flutter."
  exit 1
fi

echo "➡️  Création du .gitignore…"
cat > .gitignore <<'EOF'
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

# --- Firebase / Secrets (ne jamais commit) ---
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
EOF

if [[ ! -d ".git" ]]; then
  echo "➡️  Dépôt Git non initialisé : git init"
  git init
fi

echo "➡️  Nettoyage de l'index (retire les fichiers déjà suivis qui sont ignorés)…"
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git rm -r --cached . || true
fi

echo "➡️  Ajout des fichiers autorisés…"
git add .

if git diff --cached --quiet; then
  echo "ℹ️  Rien à committer (déjà propre)."
else
  git commit -m "chore: add Flutter .gitignore and clean repo"
fi

COUNT=$(git ls-files | wc -l | tr -d ' ')
echo "✅ Fichiers suivis par Git : $COUNT"
echo "👉 Tu devrais être dans l’ordre de quelques centaines (pas des centaines de milliers)."
echo "➡️  Prochaine étape pour publier :"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/<ton-user>/<habits_timer>.git"
echo "   git push -u origin main"
