import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the community-reported directory lives.
const String directoryUrl = 'https://dartastic.io/made-with-flutter';

/// Shown on platforms that cannot enumerate installed apps (everything
/// except Android). iOS sandboxes every app: there is no API to list other
/// installed apps, let alone read their binaries.
class UnsupportedPage extends StatelessWidget {
  const UnsupportedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Made With Flutter')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FlutterLogo(size: 96),
              const SizedBox(height: 24),
              Text(
                'Scanning is Android-only',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This platform sandboxes every app: there is no API to '
                'list the other apps on this device, let alone inspect '
                'their binaries for the Flutter engine. On Android this '
                'app detects Flutter apps, their Flutter version, and the '
                'Dart packages inside them.\n\n'
                'You can still browse the community directory of apps '
                'reported to be made with Flutter.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(directoryUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.public),
                label: const Text('Browse the community directory'),
              ),
              const SizedBox(height: 16),
              Text(
                'This app is, of course, made with Flutter.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
