import 'dart:convert';
import 'dart:io';

import 'play_web.dart';

/// One country's ranked list: `out/ranked-<cc>.json`, most-installed first.
File rankedFile(String country) =>
    File('out/ranked-${country.toLowerCase()}.json');

List<PlayApp> readRanked(File file) => file.existsSync()
    ? [
        for (final j in jsonDecode(file.readAsStringSync()) as List)
          PlayApp.fromJson(j as Map<String, Object?>),
      ]
    : [];

/// Writes [apps] sorted most-installed first.
void writeRanked(File file, Iterable<PlayApp> apps) {
  final sorted = apps.toList()
    ..sort((a, b) => (b.installs ?? -1).compareTo(a.installs ?? -1));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert([for (final a in sorted) a.toJson()]),
  );
}

/// Adds [apps] to the country's list, keeping entries already there.
/// Returns how many were new.
int mergeRanked(File file, Iterable<PlayApp> apps) {
  final byId = {for (final a in readRanked(file)) a.appId: a};
  var added = 0;
  for (final a in apps) {
    if (byId.putIfAbsent(a.appId, () => a) == a) added++;
  }
  writeRanked(file, byId.values);
  return added;
}

/// Play's search language for a storefront; English terms run everywhere.
const countryLanguage = {
  'AT': 'de',
  'BE': 'fr',
  'BR': 'pt',
  'CH': 'de',
  'DE': 'de',
  'ES': 'es',
  'FR': 'fr',
  'IT': 'it',
  'MX': 'es',
  'NL': 'nl',
  'PL': 'pl',
  'PT': 'pt',
};

/// Search terms for [country]: `terms/en.txt` plus `terms/<language>.txt`.
List<String> searchTerms(String country) {
  final lang = countryLanguage[country];
  return {
    for (final name in ['en', ?lang])
      if (File('terms/$name.txt') case final f when f.existsSync())
        for (final line in f.readAsLinesSync())
          if (line.trim() case final t when t.isNotEmpty && !t.startsWith('#'))
            t,
  }.toList();
}
