import 'package:flutter/services.dart';

import 'flutter_version_map.dart';
import 'models.dart';

/// Channel protocol shared with the Android implementation
/// (FlutterAppInspector.kt) — keep the two in sync.
const String scannerChannelName = 'io.dartastic.made_with_flutter/scanner';
const String methodListFlutterApps = 'listFlutterApps';
const String methodInspectApp = 'inspectApp';
const String methodGetAppIcon = 'getAppIcon';

/// Talks to the platform side to find and inspect Flutter apps.
///
/// Only Android can enumerate installed applications; on other platforms
/// every call throws a [MissingPluginException].
class AppScanner {
  const AppScanner();

  static const MethodChannel _channel = MethodChannel(scannerChannelName);

  /// Fast pass: all installed apps whose APKs contain libflutter.so.
  Future<List<FlutterAppInfo>> listFlutterApps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      methodListFlutterApps,
    );
    return (raw ?? const [])
        .map(FlutterAppInfo.fromChannelMap)
        .toList(growable: false);
  }

  /// Deep pass: string-scans one app's native libraries for the Dart
  /// version, snapshot hash, and package list.
  Future<FlutterAppInfo> inspect(FlutterAppInfo app) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      methodInspectApp,
      {'appId': app.appId},
    );
    var details = FlutterAppDetails.fromChannelMap(raw ?? const {});
    final estimate = estimateFlutterSeries(details.dartVersion);
    if (estimate != null) {
      details = FlutterAppDetails(
        dartVersionRaw: details.dartVersionRaw,
        dartVersion: details.dartVersion,
        dartChannel: details.dartChannel,
        flutterVersionEstimate: estimate,
        snapshotHash: details.snapshotHash,
        hasAotSnapshot: details.hasAotSnapshot,
        packages: details.packages,
      );
    }
    return app.withDetails(details);
  }

  /// The app's launcher icon as PNG bytes, or null if unavailable.
  Future<Uint8List?> appIcon(String appId) {
    return _channel.invokeMethod<Uint8List>(methodGetAppIcon, {
      'appId': appId,
    });
  }
}
