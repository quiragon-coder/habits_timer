# setup_flutter_android.ps1
# Usage: Right-click > Run with PowerShell  (or run from a PowerShell prompt)
# This script:
#  - goes to your project folder
#  - runs: flutter create .
#  - runs: flutter pub get
#  - runs: flutter run

$ErrorActionPreference = "Stop"

# >>> EDIT THESE ONLY IF YOUR PATHS ARE DIFFERENT <<<
$FlutterBat = "C:\Users\Quiragon\Desktop\flutter\bin\flutter.bat"
$ProjectDir = "C:\Users\Quiragon\Desktop\Habit timer"

Write-Host "==> Checking flutter path: $FlutterBat"
if (-not (Test-Path $FlutterBat)) {
  Write-Error "flutter.bat not found at $FlutterBat. Edit the script to point to your Flutter SDK."
}

Write-Host "==> Changing to project directory: $ProjectDir"
if (-not (Test-Path $ProjectDir)) {
  Write-Error "Project directory not found: $ProjectDir"
}
Set-Location $ProjectDir

Write-Host "==> Ensuring android/ and other native folders exist (flutter create .)"
& $FlutterBat create .

Write-Host "==> Getting dependencies (flutter pub get)"
& $FlutterBat pub get

Write-Host "==> Running the app (flutter run)"
& $FlutterBat run
