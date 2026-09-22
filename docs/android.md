# Android — Build & Install

## Quick install (today)
An installable release APK is built and committed to `dist/`:

```
dist/TowerInspection-v1.0.0.apk   (~60 MB, signed, release)
```

**Install on your phone:**
1. Copy the APK to the phone (USB, Google Drive, email to yourself, etc.)
2. On the phone, tap the APK in Files → allow "Install unknown apps" for that one app when prompted
3. Open the app. Grant Camera permission when first tapping a photo slot.

The app is fully offline — no account, no network, nothing to configure.

## Rebuild from source
```bash
export PATH=/home/professor/flutter/flutter/bin:$PATH
export ANDROID_HOME=/home/professor/android-sdk
export JAVA_HOME=/home/professor/jdk/jdk-21.0.12.1+1

flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
```
Debug build: `flutter build apk --debug`

## Signing
- Keystore: `android/app/tower-inspection-release.jks` (generated locally 2026-09-16)
- Alias `tower-inspection`, store/key password `towerinspection2026`
- Signing config lives in `android/app/build.gradle.kts`
- **Back up the keystore.** Losing it means a different signature = no updates over the installed app (would require uninstall/reinstall). For Google Play later, generate a fresh keystore and use Play App Signing.
- The password is in the gradle file for now — fine for private use; move it to an untracked `key.properties` before any public distribution.

## Verified
- `apksigner verify` passes (release cert CN=Tower Inspection, OU=Field Ops, O=Elite Tower LLC)
- Release APK 60.4 MB vs debug 160.7 MB

## Run on a device from the build machine
```bash
flutter devices          # phone via USB with USB debugging on
flutter run --release   # install + launch + logs
```
