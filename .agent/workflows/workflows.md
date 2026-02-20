---
description: description: How to build release APK and Windows executable
---

---
description: How to build release APK and Windows executable
---

# Build Release Workflow

**IMPORTANT**: Always clean before building to ensure all changes are included!

## Build Android APK
// turbo
1. Run `flutter clean` to remove old build artifacts
// turbo
2. Run `flutter build apk --release` to build the APK
3. The APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

## Build Windows Executable
// turbo
1. Kill any running instances: `taskkill /f /im prestamos_app.exe 2>$null`
// turbo
2. Run `flutter clean` to remove old build artifacts
// turbo
3. Run `flutter build windows --release` to build the executable
4. The .exe will be at: `build\windows\x64\runner\Release\prestamos_app.exe`

## Quick Build Both (Clean First)
```powershell
taskkill /f /im prestamos_app.exe 2>$null
flutter clean
flutter build apk --release
flutter build windows --release
```