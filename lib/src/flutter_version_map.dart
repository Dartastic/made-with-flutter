/// Maps a Dart SDK minor series to the Flutter stable series that shipped it.
///
/// A Flutter app's libflutter.so embeds the Dart VM version, not the Flutter
/// version, so the Flutter release can only be inferred. Minors missing from
/// this table produce no estimate rather than a guess; the raw Dart version
/// and snapshot hash still travel in shared reports so the mapping can be
/// refined server-side.
const Map<String, String> dartMinorToFlutterSeries = {
  '2.17': '3.0',
  '2.18': '3.3',
  '2.19': '3.7',
  '3.0': '3.10',
  '3.1': '3.13',
  '3.2': '3.16',
  '3.3': '3.19',
  '3.4': '3.22',
  '3.5': '3.24',
  '3.6': '3.27',
  '3.7': '3.29',
  '3.8': '3.32',
  '3.9': '3.35',
  '3.12': '3.44',
};

/// Returns the Flutter series (e.g. `3.19`) for a Dart version string
/// (e.g. `3.3.4`), or null when the Dart minor is unknown.
String? estimateFlutterSeries(String? dartVersion) {
  if (dartVersion == null) return null;
  final match = RegExp(r'^(\d+)\.(\d+)\.').firstMatch(dartVersion);
  if (match == null) return null;
  return dartMinorToFlutterSeries['${match.group(1)}.${match.group(2)}'];
}
