import 'dart:convert';
import 'dart:io';

import 'package:mwf_miner/src/adb.dart';
import 'package:mwf_miner/src/detector.dart';
import 'package:mwf_miner/src/play_installer.dart';
import 'package:mwf_miner/src/play_web.dart';
import 'package:mwf_miner/src/ranked_list.dart';

/// Consecutive non-installs that stop a run; a healthy device rarely sees
/// more than two or three.
const maxFailuresInARow = 5;

const usage = '''
Made With Flutter miner: finds which popular Play Store apps use Flutter by
driving an Android phone over adb.

  dart run bin/miner.dart check <appId>...
      Inspect apps already on the phone.
  dart run bin/miner.dart rank [--country US|DE,FR,...]
      Harvest app ids from each country's Play top charts + category pages,
      fetch exact install counts, and add them to that country's list,
      out/ranked-<cc>.json (most installed first).
  dart run bin/miner.dart search [--country DE,FR,...] [--terms <file>]
        [--min-installs 1000000]
      Run Play search for terms/en.txt plus the country's language list
      (terms/<lang>.txt), or --terms, and add every app with at least
      --min-installs installs to out/ranked-<cc>.json.
  dart run bin/miner.dart mine [<appId>...] [--country DE | --ranked <file>]
        [--limit N] [--keep] [--results out/results.jsonl]
      For each app (most installed first): install it from the Play Store on
      the phone (default list: out/ranked-us.json), inspect it, append the
      verdict to results.jsonl, and
      uninstall it again unless --keep (apps already on the phone are never
      uninstalled). Apps already in results.jsonl are skipped, so a run
      resumes where the last one stopped.

  --serial <id>   pick a device when several are connected
''';

Future<void> main(List<String> argv) async {
  if (argv.isEmpty || argv.first == '-h' || argv.first == '--help') {
    stdout.write(usage);
    return;
  }
  final args = _Args(argv.skip(1).toList());
  final adb = Adb(serial: args.option('serial'));
  try {
    switch (argv.first) {
      case 'check':
        await adb.ensureDevice();
        await _check(adb, args.positional);
      case 'rank':
        await _rank(args);
      case 'search':
        await _search(args);
      case 'mine':
        await adb.ensureDevice();
        await _mine(adb, args);
      default:
        stderr.write(usage);
        exitCode = 64;
    }
  } on DeviceException catch (e) {
    stderr.writeln('stopped: $e');
    exitCode = 1;
  }
}

Future<void> _check(Adb adb, List<String> ids) async {
  for (final id in ids) {
    final d = await detect(adb, id);
    stdout.writeln(d == null ? '$id: not installed' : _describe(d));
  }
}

String _describe(Detection d) => d.flutter
    ? '${d.appId}: FLUTTER  dart=${d.dartVersion ?? '?'}  '
          'libapp=${d.libApp}  assets=${d.flutterAssets}  v=${d.versionName}'
    : '${d.appId}: not flutter  v=${d.versionName}';

List<String> _countries(_Args args) => [
  for (final c in (args.option('country') ?? 'US').split(','))
    if (c.trim().isNotEmpty) c.trim().toUpperCase(),
];

/// Fetches install counts once for every id (they are worldwide, so any
/// storefront serves them).
Future<Map<String, PlayApp>> _details(PlayWeb web, Set<String> ids) async {
  stderr.writeln('${ids.length} apps; fetching install counts…');
  var n = 0;
  final apps = await web.detailsAll(
    ids,
    onEach: (_) {
      if (++n % 100 == 0) stderr.writeln('  $n/${ids.length}');
    },
  );
  return {for (final a in apps) a.appId: a};
}

Future<void> _rank(_Args args) async {
  final countries = _countries(args);
  final web = PlayWeb();
  try {
    final idsByCountry = <String, Set<String>>{};
    for (final country in countries) {
      final charts = PlayWeb(country: country);
      try {
        idsByCountry[country] = await charts.harvestIds();
        stderr.writeln('$country: ${idsByCountry[country]!.length} app ids');
      } finally {
        charts.close();
      }
    }
    final details = await _details(web, {
      for (final ids in idsByCountry.values) ...ids,
    });
    for (final MapEntry(key: country, value: ids) in idsByCountry.entries) {
      final file = rankedFile(country);
      final added = mergeRanked(file, [for (final id in ids) ?details[id]]);
      stderr.writeln('${file.path}: +$added (${readRanked(file).length} apps)');
    }
  } finally {
    web.close();
  }
}

Future<void> _search(_Args args) async {
  final countries = _countries(args);
  final minInstalls =
      int.tryParse(args.option('min-installs') ?? '') ?? 1000000;
  final termsFile = args.option('terms');
  final web = PlayWeb();
  try {
    final newIdsByCountry = <String, Set<String>>{};
    for (final country in countries) {
      final terms = termsFile == null
          ? searchTerms(country)
          : File(termsFile).readAsLinesSync().where((t) => t.trim().isNotEmpty);
      final known = {for (final a in readRanked(rankedFile(country))) a.appId};
      final search = PlayWeb(country: country);
      try {
        final ids = await search.searchIds(terms);
        newIdsByCountry[country] = ids.difference(known);
        stderr.writeln(
          '$country: ${terms.length} terms, ${ids.length} app ids, '
          '${newIdsByCountry[country]!.length} not yet in its list',
        );
      } finally {
        search.close();
      }
    }
    final details = await _details(web, {
      for (final ids in newIdsByCountry.values) ...ids,
    });
    for (final MapEntry(key: country, value: ids) in newIdsByCountry.entries) {
      final file = rankedFile(country);
      final added = mergeRanked(file, [
        for (final id in ids)
          if (details[id] case final a? when (a.installs ?? 0) >= minInstalls)
            a,
      ]);
      stderr.writeln('${file.path}: +$added (${readRanked(file).length} apps)');
    }
  } finally {
    web.close();
  }
}

Future<void> _mine(Adb adb, _Args args) async {
  final resultsFile = File(args.option('results') ?? 'out/results.jsonl');
  resultsFile.parent.createSync(recursive: true);
  final done = <String>{
    if (resultsFile.existsSync())
      for (final line in resultsFile.readAsLinesSync())
        if (line.trim().isNotEmpty)
          (jsonDecode(line) as Map<String, Object?>)['appId']! as String,
  };

  final List<PlayApp> queue;
  if (args.positional.isNotEmpty) {
    queue = [for (final id in args.positional) PlayApp(id, null, null)];
  } else {
    final ranked = switch (args.option('ranked')) {
      final path? => File(path),
      null => rankedFile(_countries(args).single),
    };
    queue = readRanked(ranked);
    if (queue.isEmpty) {
      throw DeviceException('${ranked.path} is missing or empty; run rank');
    }
  }
  final limit = int.tryParse(args.option('limit') ?? '');
  final keep = args.flag('keep');
  final installer = PlayInstaller(adb);

  var mined = 0;
  var failuresInARow = 0;
  for (final app in queue) {
    if (limit != null && mined >= limit) break;
    if (done.contains(app.appId)) continue;
    mined++;
    final rank = '#${queue.indexOf(app) + 1}';
    stdout.writeln(
      '$rank ${app.appId} ${app.title ?? ''} '
      '(${app.installs ?? '?'} installs)',
    );

    final outcome = await installer.install(
      app.appId,
      log: (m) => stdout.writeln('   $m'),
    );
    final record = <String, Object?>{
      ...app.toJson(),
      'install': outcome.name,
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (outcome == InstallOutcome.installed ||
        outcome == InstallOutcome.alreadyInstalled) {
      final d = await detect(adb, app.appId);
      if (d != null) {
        record.addAll(d.toJson());
        stdout.writeln('   ${_describe(d)}');
      }
      if (outcome == InstallOutcome.installed && !keep) {
        await adb.uninstall(app.appId);
      }
    } else {
      stdout.writeln('   skipped: ${outcome.name}');
    }
    resultsFile.writeAsStringSync(
      '${jsonEncode(record)}\n',
      mode: FileMode.append,
    );
    failuresInARow = switch (outcome) {
      InstallOutcome.installed || InstallOutcome.alreadyInstalled => 0,
      _ => failuresInARow + 1,
    };
    if (failuresInARow >= maxFailuresInARow) {
      throw DeviceException(
        '$maxFailuresInARow installs in a row failed; the device is likely '
        'unhealthy (network, sign-in, storage). Restart it, drop the last '
        '$maxFailuresInARow rows from ${resultsFile.path}, and rerun.',
      );
    }
  }
  await adb.shell('input keyevent KEYCODE_HOME');
}

class _Args {
  _Args(List<String> argv) {
    for (var i = 0; i < argv.length; i++) {
      final a = argv[i];
      if (a.startsWith('--')) {
        final name = a.substring(2);
        if (i + 1 < argv.length &&
            !argv[i + 1].startsWith('--') &&
            _valued.contains(name)) {
          _options[name] = argv[++i];
        } else {
          _flags.add(name);
        }
      } else {
        positional.add(a);
      }
    }
  }

  static const _valued = {
    'serial',
    'country',
    'terms',
    'min-installs',
    'ranked',
    'limit',
    'results',
  };
  final positional = <String>[];
  final _options = <String, String>{};
  final _flags = <String>{};

  String? option(String name) => _options[name];
  bool flag(String name) => _flags.contains(name);
}
