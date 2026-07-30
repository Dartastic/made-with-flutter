import 'package:flutter_test/flutter_test.dart';
import 'package:made_with_flutter/src/models.dart';

void main() {
  group('FlutterAppInfo', () {
    test('parses a channel map and serializes for the report', () {
      final app = FlutterAppInfo.fromChannelMap(<Object?, Object?>{
        'appId': 'com.example.foo',
        'name': 'Foo',
        'storeVersion': '2.1.0',
        'isSystemApp': false,
      });
      final detailed = app.withDetails(
        FlutterAppDetails.fromChannelMap(<Object?, Object?>{
          'dartVersionRaw':
              '3.3.4 (stable) (Tue Apr 16 2024) on "android_arm64"',
          'dartVersion': '3.3.4',
          'dartChannel': 'stable',
          'snapshotHash': 'aa8f8a9d40fca86266a2a1e2f93165c8',
          'hasAotSnapshot': true,
          'packages': <Object?>['http', 'provider'],
        }),
      );

      final json = detailed.toReportJson();
      expect(json['appId'], 'com.example.foo');
      expect(json['name'], 'Foo');
      expect(json['storeVersion'], '2.1.0');
      expect(json['isSystemApp'], false);
      expect(json['dartVersion'], '3.3.4');
      expect(json['dartChannel'], 'stable');
      expect(json['snapshotHash'], 'aa8f8a9d40fca86266a2a1e2f93165c8');
      expect(json['hasAotSnapshot'], true);
      expect(json['packages'], ['http', 'provider']);
    });

    test('omits absent optional fields instead of writing nulls', () {
      const app = FlutterAppInfo(appId: 'com.example.bare', name: 'Bare');
      final json = app.toReportJson();
      expect(json.containsKey('storeVersion'), isFalse);
      expect(json.containsKey('dartVersion'), isFalse);
      expect(json['isSystemApp'], false);
    });

    test('withInspectError keeps identity and records the failure', () {
      const app = FlutterAppInfo(appId: 'com.example.foo', name: 'Foo');
      final failed = app.withInspectError('boom');
      expect(failed.appId, 'com.example.foo');
      expect(failed.inspectError, 'boom');
      expect(failed.details, isNull);
    });
  });
}
