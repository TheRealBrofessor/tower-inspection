# Android — Build & Install

## Quick install

A previously built release APK exists under `dist/`. Treat it as a development artifact until release signing is rotated and the public-release audit is complete.

For development/device testing, prefer building from current source rather than redistributing an older APK.

## Rebuild from source

Set your local Flutter/Android/Java environment as appropriate for your machine, then run:

```bash
flutter pub get
flutter build apk --debug
```

For a signed release build, configure release signing first.

## Release signing

Real signing keys and passwords must stay outside git.

1. Generate a new release key for the public/distribution build. Do not reuse the key whose password appeared in earlier repository history.
2. Copy the safe template:

   ```bash
   cp android/key.properties.example android/key.properties
   ```

3. Put the real values only in `android/key.properties`.
4. Store the keystore at the path referenced by `storeFile` (for example, `android/app/your-release-key.jks`).
5. Build:

   ```bash
   flutter build apk --release
   ```

`android/key.properties`, `*.jks`, and `*.keystore` are ignored by git.

Example structure (placeholders only):

```properties
storeFile=app/your-release-key.jks
storePassword=REPLACE_WITH_SECRET
keyAlias=REPLACE_WITH_ALIAS
keyPassword=REPLACE_WITH_SECRET
```

The signing configuration in `android/app/build.gradle.kts` loads these values only when `android/key.properties` exists. Without that file, the repository contains no release credentials.

### Important history note

An earlier private-repository commit contained a signing password in source/documentation. Removing it from the current branch does not erase it from git history. Before this repository is made public:

- rotate the signing key;
- verify no keystore was ever tracked;
- scan all git history for signing material and other secrets;
- rewrite/sanitize history if needed.

Do not publish the repository until that audit is complete.

## Verify a release

After producing a signed build, verify the APK with Android build tools, for example:

```bash
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

Do not put keystore passwords, private key material, or unnecessary certificate identity details in public documentation.

## Run on a device

```bash
flutter devices
flutter run
```

For release-mode device testing after signing is configured:

```bash
flutter run --release
```

The application is designed to operate offline; test camera permissions, local persistence, report generation, and native sharing on actual target devices before distribution.
