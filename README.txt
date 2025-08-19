== Habits Timer • Outils Git ==

Contenu du ZIP :
 - fix-git-repo.ps1  (Windows / PowerShell)
 - fix_git_repo.sh   (macOS / Linux)
 - .gitignore        (au cas où, mais le script le crée déjà)

UTILISATION (Windows) :
1) Ouvre PowerShell (touche Windows, tape "PowerShell", puis Entrée).
2) Va dans le dossier de ton app (remplace par ton chemin) :
   cd "C:\Users\Quiragon\Desktop\Habit timer"
3) Copie le script dans ce dossier (ou place le ZIP ici et décompresse).
4) (Si besoin) autorise l'exécution locale :
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
5) Lance le script :
   .\fix-git-repo.ps1

Le script :
 - vérifie la présence de pubspec.yaml,
 - crée/écrase .gitignore propre,
 - init git si nécessaire,
 - nettoie l'index git,
 - commit les fichiers valides,
 - affiche le nombre de fichiers suivis.

Ensuite, publie sur GitHub :
   git branch -M main
   git remote add origin https://github.com/<ton-user>/<habits_timer>.git
   git push -u origin main
