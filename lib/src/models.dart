/// An installed application detected as built with Flutter.
class FlutterAppInfo {
  const FlutterAppInfo({
    required this.appId,
    required this.name,
    this.storeVersion,
    this.isSystemApp = false,
    this.details,
    this.inspectError,
  });

  /// Parses the map returned by the platform-side `listFlutterApps` call.
  factory FlutterAppInfo.fromChannelMap(Map<Object?, Object?> map) {
    return FlutterAppInfo(
      appId: map['appId']! as String,
      name: map['name']! as String,
      storeVersion: map['storeVersion'] as String?,
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }

  /// Application id (Android package name / iOS bundle id).
  final String appId;

  /// Human-readable launcher label.
  final String name;

  /// The version the app publisher shipped (versionName on Android).
  final String? storeVersion;

  final bool isSystemApp;

  /// Deep-inspection results; null until the app has been inspected.
  final FlutterAppDetails? details;

  /// Set when deep inspection failed; the app still counts as Flutter.
  final String? inspectError;

  FlutterAppInfo withDetails(FlutterAppDetails details) => FlutterAppInfo(
        appId: appId,
        name: name,
        storeVersion: storeVersion,
        isSystemApp: isSystemApp,
        details: details,
      );

  FlutterAppInfo withInspectError(String error) => FlutterAppInfo(
        appId: appId,
        name: name,
        storeVersion: storeVersion,
        isSystemApp: isSystemApp,
        inspectError: error,
      );

  Map<String, Object?> toReportJson() => {
        'appId': appId,
        'name': name,
        if (storeVersion != null) 'storeVersion': storeVersion,
        'isSystemApp': isSystemApp,
        if (details != null) ...details!.toReportJson(),
      };
}

/// Details extracted from a Flutter app's native libraries.
class FlutterAppDetails {
  const FlutterAppDetails({
    this.dartVersionRaw,
    this.dartVersion,
    this.dartChannel,
    this.flutterVersionEstimate,
    this.snapshotHash,
    this.hasAotSnapshot = false,
    this.packages = const [],
  });

  factory FlutterAppDetails.fromChannelMap(Map<Object?, Object?> map) {
    return FlutterAppDetails(
      dartVersionRaw: map['dartVersionRaw'] as String?,
      dartVersion: map['dartVersion'] as String?,
      dartChannel: map['dartChannel'] as String?,
      flutterVersionEstimate: map['flutterVersionEstimate'] as String?,
      snapshotHash: map['snapshotHash'] as String?,
      hasAotSnapshot: map['hasAotSnapshot'] as bool? ?? false,
      packages: (map['packages'] as List<Object?>? ?? const [])
          .cast<String>()
          .toList(growable: false),
    );
  }

  /// The full Dart VM version string found in libflutter.so, e.g.
  /// `3.12.2 (stable) (Tue Jul 15 2026) on "android_arm64"`.
  final String? dartVersionRaw;

  /// Just the semver part of [dartVersionRaw], e.g. `3.12.2`.
  final String? dartVersion;

  /// `stable`, `beta`, `dev`, or `main`.
  final String? dartChannel;

  /// Best-effort Flutter release series derived from [dartVersion].
  final String? flutterVersionEstimate;

  /// Dart VM snapshot version hash shared by libflutter.so and libapp.so,
  /// when it could be identified unambiguously.
  final String? snapshotHash;

  /// Whether a libapp.so AOT snapshot was found (false for JIT/add-to-app
  /// oddities, in which case [packages] is necessarily empty).
  final bool hasAotSnapshot;

  /// Distinct Dart package names referenced by the app's AOT snapshot.
  /// Empty for obfuscated builds.
  final List<String> packages;

  Map<String, Object?> toReportJson() => {
        if (dartVersionRaw != null) 'dartVersionRaw': dartVersionRaw,
        if (dartVersion != null) 'dartVersion': dartVersion,
        if (dartChannel != null) 'dartChannel': dartChannel,
        if (flutterVersionEstimate != null)
          'flutterVersionEstimate': flutterVersionEstimate,
        if (snapshotHash != null) 'snapshotHash': snapshotHash,
        'hasAotSnapshot': hasAotSnapshot,
        'packages': packages,
      };
}
