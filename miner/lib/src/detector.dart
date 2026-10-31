import 'dart:convert';

import 'adb.dart';

/// What the APKs of one installed app say about Flutter.
///
/// Mirrors the app's FlutterAppInspector: `libflutter.so` in any split is the
/// verdict; `libapp.so`, `flutter_assets` and the Dart VM version are detail.
/// Some Google apps (Earth, NotebookLM) ship libflutter.so without either of
/// the other two markers, so neither is required.
class Detection {
  Detection({
    required this.appId,
    required this.flutter,
    required this.libApp,
    required this.flutterAssets,
    required this.dartVersion,
    required this.versionName,
  });

  final String appId;
  final bool flutter;
  final bool libApp;
  final bool flutterAssets;
  final String? dartVersion;
  final String? versionName;

  Map<String, Object?> toJson() => {
    'appId': appId,
    'flutter': flutter,
    'libApp': libApp,
    'flutterAssets': flutterAssets,
    'dartVersion': dartVersion,
    'versionName': versionName,
  };
}

/// Same pattern as FlutterAppInspector.DART_VERSION.
final dartVersionPattern = RegExp(
  r'\d+\.\d+\.\d+[0-9A-Za-z.\-]* \((stable|beta|dev|main|be)\) '
  r'\([^)]{1,80}\) on "android_[a-z0-9_]+"',
);

final _libFlutter = RegExp(r'lib/[^/\s]+/libflutter\.so');

Future<Detection?> detect(Adb adb, String appId) async {
  final apks = await adb.apkPaths(appId);
  if (apks.isEmpty) return null;

  String? libFlutterApk;
  String? libFlutterEntry;
  var libApp = false;
  var assets = false;
  for (final apk in apks) {
    final listing = await adb.shell("unzip -l '$apk' 2>/dev/null");
    final entry = _libFlutter.firstMatch(listing)?.group(0);
    // Prefer the 64-bit ARM engine when an APK carries several ABIs.
    if (entry != null && (libFlutterEntry == null || entry.contains('arm64'))) {
      libFlutterApk = apk;
      libFlutterEntry = entry;
    }
    libApp |= RegExp(r'lib/[^/\s]+/libapp\.so').hasMatch(listing);
    assets |= listing.contains('assets/flutter_assets/');
  }

  String? dartVersion;
  if (libFlutterApk != null) {
    final bytes = await adb.execOutBytes(
      "unzip -p '$libFlutterApk' '$libFlutterEntry'",
    );
    dartVersion = dartVersionPattern
        .firstMatch(latin1.decode(bytes, allowInvalid: true))
        ?.group(0)
        ?.split(' ')
        .first;
  }

  return Detection(
    appId: appId,
    flutter: libFlutterApk != null,
    libApp: libApp,
    flutterAssets: assets,
    dartVersion: dartVersion,
    versionName: await adb.versionName(appId),
  );
}
