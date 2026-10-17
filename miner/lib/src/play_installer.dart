import 'adb.dart';

enum InstallOutcome {
  alreadyInstalled,
  installed,
  notOffered, // paid, incompatible, unavailable in region, or not found
  unrecognized, // the details page showed none of the states we know
  installFailed, // the Play Store said "Can't install"
  timedOut,
}

class UiNode {
  UiNode(this.text, this.desc, this.x, this.y, this.enabled);
  final String text;
  final String desc;
  final int x;
  final int y;
  final bool enabled;
  String get label => text.isNotEmpty ? text : desc;
}

final _node = RegExp(r'<node [^>]*>');
String _attr(String node, String name) =>
    RegExp('$name="([^"]*)"').firstMatch(node)?.group(1) ?? '';

List<UiNode> parseUi(String xml) {
  final nodes = <UiNode>[];
  for (final m in _node.allMatches(xml)) {
    final n = m.group(0)!;
    final b = RegExp(
      r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',
    ).firstMatch(_attr(n, 'bounds'));
    if (b == null) continue;
    final v = [for (var i = 1; i <= 4; i++) int.parse(b.group(i)!)];
    nodes.add(
      UiNode(
        _attr(n, 'text'),
        _attr(n, 'content-desc'),
        (v[0] + v[2]) ~/ 2,
        (v[1] + v[3]) ~/ 2,
        _attr(n, 'enabled') == 'true',
      ),
    );
  }
  return nodes;
}

/// Installs apps by driving the Play Store app on the phone: open the
/// details page, tap Install, and wait for the package manager to see it.
class PlayInstaller {
  PlayInstaller(this.adb, {this.timeout = const Duration(minutes: 8)});

  final Adb adb;
  final Duration timeout;

  Future<InstallOutcome> install(
    String appId, {
    void Function(String)? log,
  }) async {
    if (await adb.isInstalled(appId)) return InstallOutcome.alreadyInstalled;
    await adb.wake();
    await adb.shell(
      'am start -a android.intent.action.VIEW '
      '-d "market://details?id=$appId" -p com.android.vending',
    );

    // Find and tap Install; the page takes a few seconds to render.
    var tapped = false;
    for (var i = 0; i < 10 && !tapped; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final nodes = parseUi(await adb.dumpUi());
      final install = nodes.where((n) => n.enabled && n.label == 'Install');
      if (install.isNotEmpty) {
        await adb.tap(install.first.x, install.first.y);
        tapped = true;
        log?.call('tapped Install');
        break;
      }
      if (nodes.any((n) => n.label == 'Sign in')) {
        throw DeviceException(
          'the Play Store is signed out; sign in on the device and rerun',
        );
      }
      if (nodes.any((n) => n.label == 'Open' || n.label == 'Uninstall')) {
        break; // Installed while we looked (or a work-profile copy).
      }
      if (nodes.any(
        (n) =>
            RegExp(
              r"isn't compatible|not available|not found|"
              r'Item not found',
            ).hasMatch(n.label) ||
            RegExp(r'^\$\d').hasMatch(n.label),
      )) {
        return InstallOutcome.notOffered;
      }
    }
    if (!tapped && !await adb.isInstalled(appId)) {
      return InstallOutcome.unrecognized;
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await adb.isInstalled(appId)) return InstallOutcome.installed;
      await Future<void>.delayed(const Duration(seconds: 5));
      final nodes = parseUi(await adb.dumpUi());
      if (nodes.any((n) => n.label.startsWith("Can't install"))) {
        final ok = nodes.where((n) => n.label == 'Got it');
        if (ok.isNotEmpty) await adb.tap(ok.first.x, ok.first.y);
        return InstallOutcome.installFailed;
      }
    }
    return InstallOutcome.timedOut;
  }
}
