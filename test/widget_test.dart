import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:made_with_flutter/main.dart';
import 'package:made_with_flutter/src/scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockScannerChannel(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(scannerChannelName),
      (call) async {
        switch (call.method) {
          case methodListFlutterApps:
            return <Object?>[
              <Object?, Object?>{
                'appId': 'com.example.foo',
                'name': 'Foo',
                'storeVersion': '1.0.0',
                'isSystemApp': false,
              },
            ];
          case methodInspectApp:
            return <Object?, Object?>{
              'dartVersionRaw':
                  '3.3.4 (stable) (Tue Apr 16 2024) on "android_arm64"',
              'dartVersion': '3.3.4',
              'dartChannel': 'stable',
              'snapshotHash': 'aa8f8a9d40fca86266a2a1e2f93165c8',
              'hasAotSnapshot': true,
              'packages': <Object?>['http', 'provider'],
            };
          case methodGetAppIcon:
            return null;
        }
        return null;
      },
    );
  }

  testWidgets('Android: scanning lists detected Flutter apps',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockScannerChannel(tester);

    await tester.pumpWidget(const MadeWithFlutterApp());
    expect(find.text('Scan installed apps'), findsOneWidget);

    await tester.tap(find.text('Scan installed apps'));
    await tester.pumpAndSettle();

    expect(find.text('Foo'), findsOneWidget);
    expect(find.text('com.example.foo'), findsOneWidget);
    expect(find.text('Flutter ~3.19'), findsOneWidget);
    expect(
      find.text('1 app(s) on this device are made with Flutter'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('non-Android platforms get the sandbox explainer',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(const MadeWithFlutterApp());
    expect(find.text('Scanning is Android-only'), findsOneWidget);
    expect(find.text('Browse the community directory'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
