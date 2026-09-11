import 'package:flutter/material.dart';

/// The quiet editing surface, separate from colors used on the playback screen.
abstract final class SlideEditorStyle {
  static const ink = Color(0xFF202028);
  static const muted = Color(0xFF777683);
  static const accent = Color(0xFF77729D);
  static const surface = Color(0xFFF5F4F8);
  static const wheel = Color(0xFFE4E1EE);
  static const line = Color(0xFFE6E3EF);

  static ThemeData theme(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLow: surface,
      surfaceContainerHighest: wheel,
      outlineVariant: line,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: const TextStyle(color: muted, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accent),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? wheel : surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : muted,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : wheel,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
