# iOS — Status & Build Procedure

## Current state
The complete iOS Flutter project exists (`ios/` — Runner, AppDelegate, Info.plist with camera
usage description, Podfile with permission macros, Assets). It is **platform-correct source,
not compiled**: this Linux machine cannot run Xcode.

## What remains (requires a Mac)
1. On any Mac with Xcode 15+ and CocoaPods (`sudo gem install cocoapods`):
   ```bash
   cd tower-inspection
   flutter pub get
   cd ios && pod install && cd ..
   open ios/Runner.xcworkspace
   ```
2. In Xcode: set your Team under Signing & Capabilities (free Apple ID works for personal-device installs)
3. Plug in iPhone → select it → Run. Or `flutter run --release` / `flutter build ipa`.

## Verified without Xcode
- Info.plist carries `NSCameraUsageDescription` (camera) and photo-library usage descriptions
- Podfile platform iOS 15 with permission_handler macro flags
- All Dart code is platform-neutral; only share_plus/printing/camera plugins touch platform channels (officially supported on iOS)
- Full iOS compile/signing is the only untested step and needs macOS (Apple's toolchain requirement, not a code gap)

## Notes
- TestFlight/App Store distribution additionally requires a paid Apple Developer account ($99/yr)
- First camera use will trigger the iOS permission dialog — the strings in Info.plist are what the user sees
