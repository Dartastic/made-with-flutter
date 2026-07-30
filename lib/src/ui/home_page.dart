import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../scan_controller.dart';
import 'app_detail_page.dart';
import 'unsupported_page.dart';

/// Landing page: scans on Android, explains the sandbox everywhere else.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  /// Injectable for widget tests; the page creates its own otherwise.
  final ScanController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScanController _controller = widget.controller ?? ScanController();

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share with dartastic.io?'),
        content: Text(
          'This sends the ${_controller.apps.length} detected Flutter '
          'app(s) — ids, names, versions, Dart/Flutter versions and package '
          'lists — plus your Android version and a random install id to the '
          'public Made With Flutter directory at dartastic.io. '
          'No account and no personal data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.share();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report shared with dartastic.io.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const UnsupportedPage();
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final done = _controller.phase == ScanPhase.done;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Made With Flutter'),
            actions: [
              if (done && _controller.apps.isNotEmpty)
                IconButton(
                  icon: _controller.sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _controller.shared
                              ? Icons.cloud_done
                              : Icons.cloud_upload_outlined,
                        ),
                  tooltip: 'Share report with dartastic.io',
                  onPressed: _controller.sharing ? null : _share,
                ),
            ],
          ),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    switch (_controller.phase) {
      case ScanPhase.idle:
        return _Intro(onScan: _controller.scan);
      case ScanPhase.listing:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Finding Flutter apps…'),
            ],
          ),
        );
      case ScanPhase.inspecting:
      case ScanPhase.done:
        return _resultList(context);
      case ScanPhase.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Scan failed: ${_controller.error}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _controller.scan,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _resultList(BuildContext context) {
    final apps = _controller.apps;
    final inspecting = _controller.phase == ScanPhase.inspecting;
    return Column(
      children: [
        if (inspecting)
          LinearProgressIndicator(
            value: apps.isEmpty ? null : _controller.inspected / apps.length,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  inspecting
                      ? 'Inspecting ${_controller.inspected} of '
                          '${apps.length} Flutter apps…'
                      : '${apps.length} app(s) on this device are '
                          'made with Flutter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!inspecting)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rescan',
                  onPressed: _controller.scan,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return _AppTile(
                app: app,
                icon: _controller.icons[app.appId],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppDetailPage(
                      app: app,
                      icon: _controller.icons[app.appId],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlutterLogo(size: 96),
            const SizedBox(height: 24),
            Text(
              'Which of your apps are made with Flutter?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Scans the apps installed on this device for the Flutter '
              'engine, and inspects each one for its Flutter version and '
              'the Dart packages it uses. Everything runs on-device; '
              'nothing leaves your phone unless you share the report.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.search),
              label: const Text('Scan installed apps'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.onTap, this.icon});

  final FlutterAppInfo app;
  final Uint8List? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = app.details;
    final String trailing;
    if (details?.flutterVersionEstimate != null) {
      trailing = 'Flutter ~${details!.flutterVersionEstimate}';
    } else if (details?.dartVersion != null) {
      trailing = 'Dart ${details!.dartVersion}';
    } else if (app.inspectError != null) {
      trailing = 'inspect failed';
    } else if (details == null) {
      trailing = '…';
    } else {
      trailing = '';
    }
    return ListTile(
      leading: icon != null
          ? Image.memory(icon!, width: 40, height: 40)
          : const FlutterLogo(size: 40),
      title: Text(app.name),
      subtitle: Text(app.appId),
      trailing: trailing.isEmpty ? null : Text(trailing),
      onTap: onTap,
    );
  }
}
