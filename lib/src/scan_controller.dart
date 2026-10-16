import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models.dart';
import 'report.dart';
import 'scanner.dart';

enum ScanPhase { idle, listing, inspecting, done, failed }

/// Orchestrates the scan: fast list pass, then per-app deep inspection,
/// notifying after each app so the UI fills in progressively.
class ScanController extends ChangeNotifier {
  ScanController({
    this.scanner = const AppScanner(),
    this.uploader = const ReportUploader(),
  });

  final AppScanner scanner;
  final ReportUploader uploader;

  ScanPhase phase = ScanPhase.idle;
  List<FlutterAppInfo> apps = [];
  final Map<String, Uint8List> icons = {};
  int inspected = 0;
  String? error;
  bool sharing = false;
  bool shared = false;

  Future<void> scan() async {
    phase = ScanPhase.listing;
    apps = [];
    icons.clear();
    inspected = 0;
    error = null;
    shared = false;
    notifyListeners();
    try {
      apps = List.of(await scanner.listFlutterApps());
      phase = ScanPhase.inspecting;
      notifyListeners();
      for (var i = 0; i < apps.length; i++) {
        final app = apps[i];
        try {
          final icon = await scanner.appIcon(app.appId);
          if (icon != null) icons[app.appId] = icon;
        } catch (_) {
          // An unloadable icon is cosmetic; keep scanning.
        }
        try {
          apps[i] = await scanner.inspect(app);
        } catch (e) {
          apps[i] = app.withInspectError(e.toString());
        }
        inspected = i + 1;
        notifyListeners();
      }
      phase = ScanPhase.done;
    } catch (e) {
      error = e.toString();
      phase = ScanPhase.failed;
    }
    notifyListeners();
  }

  /// Uploads the scan results to dartastic.io. Rethrows failures so the UI
  /// can show them.
  Future<void> share() async {
    if (apps.isEmpty || sharing) return;
    sharing = true;
    notifyListeners();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final report = ScanReport(
        installId: await installId(),
        platform: Platform.operatingSystem,
        osVersion: Platform.operatingSystemVersion,
        appVersion: packageInfo.version,
        apps: apps,
      );
      await uploader.upload(report);
      shared = true;
    } finally {
      sharing = false;
      notifyListeners();
    }
  }
}
