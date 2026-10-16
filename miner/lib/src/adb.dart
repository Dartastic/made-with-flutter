import 'dart:convert';
import 'dart:io';

/// Thin wrapper over the `adb` binary for one connected device.
class Adb {
  Adb({this.serial, String? adbPath}) : _adb = adbPath ?? _findAdb();

  /// Device to target when several are connected.
  final String? serial;
  final String _adb;

  static String _findAdb() {
    final sdk =
        Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'] ??
        '${Platform.environment['HOME']}/Library/Android/sdk';
    final candidate = '$sdk/platform-tools/adb';
    return File(candidate).existsSync() ? candidate : 'adb';
  }

  List<String> _args(List<String> args) => [
    if (serial case final s?) ...['-s', s],
    ...args,
  ];

  /// Runs `adb shell <command>` and returns stdout (CRs stripped).
  Future<String> shell(String command) async {
    final r = await Process.run(
      _adb,
      _args(['shell', command]),
      stdoutEncoding: latin1,
    );
    return (r.stdout as String).replaceAll('\r', '');
  }

  /// Runs `adb exec-out <command>` and returns raw stdout bytes.
  Future<List<int>> execOutBytes(String command) async {
    final r = await Process.run(
      _adb,
      _args(['exec-out', command]),
      stdoutEncoding: null,
    );
    return r.stdout as List<int>;
  }

  Future<ProcessResult> run(List<String> args) =>
      Process.run(_adb, _args(args));

  Future<List<String>> devices() async {
    final r = await Process.run(_adb, ['devices']);
    return (r.stdout as String)
        .split('\n')
        .skip(1)
        .where((l) => l.trim().endsWith('device'))
        .map((l) => l.split(RegExp(r'\s+')).first)
        .toList();
  }

  /// APK paths (base + splits) for an installed package; empty if absent.
  Future<List<String>> apkPaths(String appId) async {
    final out = await shell('pm path $appId');
    return out
        .split('\n')
        .where((l) => l.startsWith('package:'))
        .map((l) => l.substring('package:'.length).trim())
        .toList();
  }

  Future<bool> isInstalled(String appId) async =>
      (await apkPaths(appId)).isNotEmpty;

  Future<String?> versionName(String appId) async {
    final out = await shell('dumpsys package $appId');
    return RegExp(r'versionName=(\S+)').firstMatch(out)?.group(1);
  }

  Future<void> uninstall(String appId) => run(['uninstall', appId]);

  Future<void> tap(int x, int y) => shell('input tap $x $y');

  Future<void> wake() => shell('input keyevent KEYCODE_WAKEUP');

  /// Dumps the current UI hierarchy; retries because uiautomator fails while
  /// the screen is animating.
  Future<String> dumpUi() async {
    for (var i = 0; i < 4; i++) {
      final out = await shell(
        'uiautomator dump /sdcard/mwf_ui.xml >/dev/null 2>&1 && cat /sdcard/mwf_ui.xml',
      );
      if (out.contains('<hierarchy')) return out;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return '';
  }
}
