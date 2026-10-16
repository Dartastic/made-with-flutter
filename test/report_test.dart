import 'package:flutter_test/flutter_test.dart';
import 'package:made_with_flutter/src/models.dart';
import 'package:made_with_flutter/src/report.dart';

void main() {
  test('ScanReport serializes the full payload shape', () {
    const report = ScanReport(
      installId: 'abc123',
      platform: 'android',
      osVersion: '14',
      appVersion: '0.1.0',
      apps: [
        FlutterAppInfo(appId: 'com.example.foo', name: 'Foo'),
        FlutterAppInfo(appId: 'com.example.bar', name: 'Bar'),
      ],
    );

    final json = report.toJson();
    expect(json['schemaVersion'], 1);
    expect(json['installId'], 'abc123');
    expect(json['platform'], 'android');
    expect(json['osVersion'], '14');
    expect(json['reporterAppVersion'], '0.1.0');
    final apps = json['apps']! as List<Object?>;
    expect(apps, hasLength(2));
    expect((apps.first! as Map<String, Object?>)['appId'], 'com.example.foo');
  });

  test('report endpoint defaults to dartastic.io', () {
    expect(
      reportEndpoint,
      'https://dartastic.io/api/made-with-flutter/reports',
    );
  });
}
