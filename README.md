# Made With Flutter

A Flutter app that reports which apps on your device are made with Flutter,
which Flutter version they use, and which Dart packages are inside them.
Detected apps can be shared with the public community directory at
[dartastic.io/made-with-flutter](https://dartastic.io/made-with-flutter).

## How detection works

**Android** (full support):

1. Every installed application's APKs (base + splits) are checked for
   `lib/<abi>/libflutter.so` — the Flutter engine. Present ⇒ made with
   Flutter.
2. `libflutter.so` embeds the Dart VM version string (for example
   `3.3.4 (stable) (…) on "android_arm64"`). The Flutter release is inferred
   from the Dart minor via a bundled mapping table
   (`lib/src/flutter_version_map.dart`); since the engine does not embed the
   Flutter version itself, it is always shown as an estimate (`~3.19`).
3. `libapp.so` — the app's Dart AOT snapshot — retains `package:name/…` URIs
   from source positions. Scanning it yields the distinct Dart packages the
   app uses. Apps built with `--obfuscate` yield none, and are labeled as
   such.
4. The 32-hex snapshot version hash shared by `libflutter.so` and
   `libapp.so` is included in reports so the version mapping can be refined
   server-side.

All scanning happens on-device. Nothing leaves the device unless you tap
Share, and the confirmation dialog spells out exactly what is sent (detected
apps, versions, package lists, Android version, and a random install id used
only to de-duplicate re-submissions).

**iOS**: not possible, by design of the platform. iOS sandboxes every app —
there is no API to enumerate other installed apps, let alone read their
binaries. The app runs on iOS but shows an explainer and links to the
community directory instead. (This is also why comparable detector apps are
Android-only.)

Android note: the app declares `QUERY_ALL_PACKAGES`, since enumerating all
installed apps is its core function. Google Play requires a permission
declaration for that at listing time.

## Development

```sh
flutter pub get
flutter analyze   # zero issues, including info-level
flutter test
flutter run       # on an Android device to actually scan
```

The report endpoint defaults to production and can be pointed elsewhere for
testing:

```sh
flutter run --dart-define=MWF_REPORT_ENDPOINT=https://dev.dartastic.io/api/made-with-flutter/reports
```

The platform-channel protocol lives in `lib/src/scanner.dart` (Dart) and
`android/.../FlutterAppInspector.kt` (Kotlin) — keep them in sync.
