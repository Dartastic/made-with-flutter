import 'dart:convert';
import 'dart:io';

import 'package:mwf_miner/src/adb.dart';
import 'package:mwf_miner/src/detector.dart';
import 'package:mwf_miner/src/play_installer.dart';
import 'package:mwf_miner/src/play_web.dart';

const usage = '''
Made With Flutter miner: finds which popular Play Store apps use Flutter by
driving an Android phone over adb.

  dart run bin/miner.dart check <appId>...
      Inspect apps already on the phone.
  dart run bin/miner.dart rank [--out out/ranked.json] [--country US]
      Harvest app ids from Play top charts + category pages, fetch exact
      install counts, write them sorted most-installed first.
  dart run bin/miner.dart mine [<appId>...] [--ranked out/ranked.json]
        [--limit N] [--keep] [--results out/results.jsonl]
      For each app (most installed first): install it from the Play Store on
      the phone, inspect it, append the verdict to results.jsonl, and
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
  switch (argv.first) {
    case 'check':
      await _check(adb, args.positional);
    case 'rank':
      await _rank(args);
    case 'mine':
      await _mine(adb, args);
    default:
      stderr.write(usage);
      exitCode = 64;
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

Future<void> _rank(_Args args) async {
  final out = File(args.option('out') ?? 'out/ranked.json');
  final web = PlayWeb(country: args.option('country') ?? 'US');
  try {
    final ids = await web.harvestIds(log: stderr.writeln);
    stderr.writeln('${ids.length} unique app ids; fetching install counts…');
    var n = 0;
    final apps = await web.detailsAll(
      ids,
      onEach: (_) {
        if (++n % 50 == 0) stderr.writeln('  $n/${ids.length}');
      },
    );
    apps.sort((a, b) => (b.installs ?? -1).compareTo(a.installs ?? -1));
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert([for (final a in apps) a.toJson()]),
    );
    stderr.writeln('wrote ${apps.length} apps to ${out.path}');
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
    final ranked = File(args.option('ranked') ?? 'out/ranked.json');
    queue = [
      for (final j in jsonDecode(ranked.readAsStringSync()) as List)
        PlayApp.fromJson(j as Map<String, Object?>),
    ];
  }
  final limit = int.tryParse(args.option('limit') ?? '');
  final keep = args.flag('keep');
  final installer = PlayInstaller(adb);

  var mined = 0;
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
    'out',
    'country',
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
