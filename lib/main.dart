import 'package:flutter/material.dart';

import 'src/ui/home_page.dart';

void main() {
  runApp(const MadeWithFlutterApp());
}

/// Root widget for Made With Flutter.
class MadeWithFlutterApp extends StatelessWidget {
  const MadeWithFlutterApp({super.key});

  static const Color _flutterBlue = Color(0xFF0468D7);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Made With Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _flutterBlue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _flutterBlue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}
