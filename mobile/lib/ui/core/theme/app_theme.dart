import 'package:flutter/material.dart';

/// M3 design tokens for WheelDeck.
/// 60/30/10 + 8pt grid. Single seed → consistent light/dark schemes.
abstract final class AppTheme {
  static const _seed = Colors.blue;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        // Max 4 sizes / 2 weights — M3 defaults cover this; override only if needed.
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
