import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';

/// Shared modal styling, matching the quiet lavender editing surfaces.
abstract final class AppDialogTheme {
  static const surface = AppColors.dialog;
  static const ink = AppColors.ink;
  static const muted = AppColors.muted;
  static const accent = AppColors.accent;
  static const line = AppColors.line;
  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppStyle.cardRadius)),
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
    final guide = base.extension<AppStyle>() ?? const AppStyle();
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppStyle.controlRadius)),
    );
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppStyle.controlRadius)),
      borderSide: BorderSide(color: line),
    );
    return base.copyWith(
      dialogTheme: data.copyWith(
        titleTextStyle: base.textTheme.titleLarge
            ?.merge(guide.subText2)
            .copyWith(color: ink),
      ),
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
          borderRadius: BorderRadius.all(
            Radius.circular(AppStyle.controlRadius),
          ),
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
          minimumSize: Size(88, guide.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          shape: buttonShape,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          foregroundColor: accent,
          minimumSize: Size(88, guide.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: line),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          foregroundColor: muted,
          minimumSize: Size(64, guide.buttonHeight),
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
