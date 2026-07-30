import 'package:flutter_test/flutter_test.dart';
import 'package:made_with_flutter/src/flutter_version_map.dart';

void main() {
  group('estimateFlutterSeries', () {
    test('maps known Dart minors to Flutter series', () {
      expect(estimateFlutterSeries('2.18.0'), '3.3');
      expect(estimateFlutterSeries('3.3.4'), '3.19');
      expect(estimateFlutterSeries('3.9.0'), '3.35');
      expect(estimateFlutterSeries('3.12.2'), '3.44');
    });

    test('patch and prerelease segments do not affect the series', () {
      expect(estimateFlutterSeries('3.3.0'), '3.19');
      expect(estimateFlutterSeries('3.3.99'), '3.19');
    });

    test('unknown minors produce no estimate rather than a guess', () {
      expect(estimateFlutterSeries('3.10.0'), isNull);
      expect(estimateFlutterSeries('1.24.3'), isNull);
    });

    test('malformed input produces null', () {
      expect(estimateFlutterSeries(null), isNull);
      expect(estimateFlutterSeries(''), isNull);
      expect(estimateFlutterSeries('not a version'), isNull);
      expect(estimateFlutterSeries('3.3'), isNull);
    });
  });
}
