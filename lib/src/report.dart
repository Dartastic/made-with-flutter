import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Where shared reports are sent. Override for dev/test environments with
/// --dart-define=MWF_REPORT_ENDPOINT=...
const String reportEndpoint = String.fromEnvironment(
  'MWF_REPORT_ENDPOINT',
  defaultValue: 'https://dartastic.io/api/made-with-flutter/reports',
);

/// A report of the Flutter apps found on one device.
class ScanReport {
  const ScanReport({
    required this.installId,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.apps,
  });

  /// Random id identifying this install, so re-submissions from the same
  /// device can be de-duplicated. Carries no personal information.
  final String installId;

  /// `android` or `ios`.
  final String platform;

  final String osVersion;

  /// This app's own version, so payload quirks can be traced to a release.
  final String appVersion;

  final List<FlutterAppInfo> apps;

  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'installId': installId,
        'platform': platform,
        'osVersion': osVersion,
        'reporterAppVersion': appVersion,
        'apps': [for (final app in apps) app.toReportJson()],
      };
}

class ReportUploadException implements Exception {
  ReportUploadException(this.message);
  final String message;

  @override
  String toString() => 'ReportUploadException: $message';
}

/// Sends a [ScanReport] to the Dartastic endpoint. Throws on any failure —
/// the UI reports it; nothing is silently dropped.
class ReportUploader {
  const ReportUploader();

  Future<void> upload(ScanReport report) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(reportEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(report.toJson()),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw ReportUploadException('Could not reach $reportEndpoint: $e');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ReportUploadException(
        'HTTP ${response.statusCode} from $reportEndpoint: ${response.body}',
      );
    }
  }
}

const String _installIdPrefsKey = 'installId';

/// Returns this install's stable random id, minting it on first use.
Future<String> installId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_installIdPrefsKey);
  if (existing != null) return existing;
  final random = Random.secure();
  final id = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await prefs.setString(_installIdPrefsKey, id);
  return id;
}
