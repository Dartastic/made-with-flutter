import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';

/// Everything extracted from one detected Flutter app.
class AppDetailPage extends StatelessWidget {
  const AppDetailPage({super.key, required this.app, this.icon});

  final FlutterAppInfo app;
  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    final details = app.details;
    return Scaffold(
      appBar: AppBar(title: Text(app.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              icon != null
                  ? Image.memory(icon!, width: 56, height: 56)
                  : const FlutterLogo(size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SelectableText(app.appId),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(context, 'App'),
          _row('Version', app.storeVersion ?? 'unknown'),
          _row('System app', app.isSystemApp ? 'yes' : 'no'),
          const SizedBox(height: 16),
          _section(context, 'Flutter build'),
          if (app.inspectError != null)
            _row('Inspection failed', app.inspectError!)
          else if (details == null)
            const _KeyValueRow(label: 'Status', value: 'not yet inspected')
          else ...[
            _row('Dart version', details.dartVersionRaw ?? 'not found'),
            _row(
              'Flutter version',
              details.flutterVersionEstimate != null
                  ? '~${details.flutterVersionEstimate} '
                      '(inferred from the Dart version)'
                  : 'unknown',
            ),
            _row('Channel', details.dartChannel ?? 'unknown'),
            _row('Snapshot hash', details.snapshotHash ?? 'not identified'),
            const SizedBox(height: 16),
            _section(
              context,
              'Dart packages (${details.packages.length})',
            ),
            if (details.packages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  details.hasAotSnapshot
                      ? 'No package names found — this app was likely '
                          'built with --obfuscate.'
                      : 'No AOT snapshot (libapp.so) found, so packages '
                          'cannot be read.',
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final package in details.packages)
                    Chip(label: Text(package)),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _row(String label, String value) =>
      _KeyValueRow(label: label, value: value);
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
