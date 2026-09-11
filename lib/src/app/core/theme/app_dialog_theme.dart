import 'package:flutter/material.dart';

/// Shared modal styling, matching the quiet lavender editing surfaces.
abstract final class AppDialogTheme {
  static const surface = Color(0xFFF7F6FA);
  static const ink = Color(0xFF202028);
  static const muted = Color(0xFF777683);
  static const accent = Color(0xFF77729D);
  static const line = Color(0xFFE6E3EF);
  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  static const insetPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 24,
  );

  static const data = DialogThemeData(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: shape,
    insetPadding: insetPadding,
    titleTextStyle: TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    contentTextStyle: TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      height: 1.5,
      color: muted,
    ),
    actionsPadding: EdgeInsets.fromLTRB(24, 8, 24, 24),
  );

  /// Scoped to dialogs so playback colors and page actions keep their meaning.
  static ThemeData of(ThemeData base) {
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: line),
    );
    return base.copyWith(
      dialogTheme: data,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: line,
        outlineVariant: line,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: muted, fontSize: 14),
        floatingLabelStyle: TextStyle(color: accent, fontSize: 14),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        prefixIconColor: muted,
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: line,
          disabledForegroundColor: muted,
          minimumSize: const Size(88, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: buttonShape,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(88, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: line),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: muted,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: buttonShape,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: ink,
        collapsedTextColor: ink,
        iconColor: muted,
        collapsedIconColor: muted,
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
