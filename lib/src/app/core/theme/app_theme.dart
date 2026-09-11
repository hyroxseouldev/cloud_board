import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/theme/app_dialog_theme.dart';

// Kept for existing callers; display-mode black is intentionally unchanged.
abstract final class XonColors {
  static const black = Color(0xFF050505);
  static const pale = AppColors.surface;
  static const line = AppColors.line;
  static const muted = AppColors.muted;
}

abstract final class XonTheme {
  static Widget responsiveBuilder(BuildContext context, Widget? child) => Theme(
    data: AppTheme.apply(
      Theme.of(context),
      style: AppStyle(compact: MediaQuery.sizeOf(context).shortestSide < 600),
    ),
    child: child ?? const SizedBox.shrink(),
  );

  static ThemeData get light =>
      AppTheme.apply(ThemeData(fontFamily: 'Pretendard'));
}

abstract final class AppTheme {
  static ThemeData apply(ThemeData base, {AppStyle? style}) {
    final guide = style ?? base.extension<AppStyle>() ?? const AppStyle();
    final text = base.textTheme
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.merge(guide.mainText),
          headlineLarge: base.textTheme.headlineLarge?.merge(guide.mainText),
          headlineMedium: base.textTheme.headlineMedium?.merge(guide.subText1),
          headlineSmall: base.textTheme.headlineSmall?.merge(guide.subText2),
          titleLarge: base.textTheme.titleLarge?.merge(guide.subText3),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    return base.copyWith(
      extensions: [
        ...base.extensions.values.where((value) => value is! AppStyle),
        guide,
      ],
      scaffoldBackgroundColor: Colors.white,
      dialogTheme: AppDialogTheme.data.copyWith(
        titleTextStyle: base.textTheme.titleLarge
            ?.merge(guide.subText2)
            .copyWith(color: AppColors.ink),
      ),
      textTheme: text,
      iconTheme: base.iconTheme.copyWith(
        color: AppColors.muted,
        size: guide.iconSize,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: guide.iconSize,
          minimumSize: Size.square(guide.buttonHeight),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        primaryContainer: AppColors.selected,
        onPrimaryContainer: AppColors.ink,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.selected,
        onSecondaryContainer: AppColors.ink,
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.selected,
        onTertiaryContainer: AppColors.ink,
        surfaceContainerLowest: Colors.white,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.selected,
        outline: AppColors.muted,
        surfaceContainerLow: AppColors.surface,
        surfaceContainerHighest: AppColors.selected,
        outlineVariant: AppColors.line,
      ),
      appBarTheme: AppBarTheme(
        titleTextStyle: base.textTheme.titleLarge
            ?.merge(guide.subText2)
            .copyWith(color: AppColors.ink),
        toolbarHeight: guide.primaryButtonHeight,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: AppColors.accent,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        constraints: BoxConstraints(minHeight: guide.buttonHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.cardRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: AppColors.line,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.selected,
        secondarySelectedColor: AppColors.selected,
        checkmarkColor: AppColors.accent,
        side: BorderSide.none,
        labelStyle: base.textTheme.labelLarge?.copyWith(color: AppColors.ink),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: AppColors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.controlRadius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        sizeConstraints: BoxConstraints.tightFor(
          width: guide.floatingSize,
          height: guide.floatingSize,
        ),
        iconSize: guide.iconSize,
        extendedSizeConstraints: BoxConstraints(minHeight: guide.buttonHeight),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            guide.compact ? AppStyle.cardRadius : AppStyle.floatingRadius,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.accent,
        dividerColor: AppColors.line,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          iconSize: guide.iconSize,
          minimumSize: Size(64, guide.buttonHeight),
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          foregroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          iconSize: guide.iconSize,
          minimumSize: Size(64, guide.buttonHeight),
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          backgroundColor: AppColors.selected,
          foregroundColor: AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: Colors.white,
        ),
        actionTextColor: Colors.white,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surface,
        headerForegroundColor: AppColors.ink,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: Colors.white,
        dialBackgroundColor: AppColors.surface,
        dialHandColor: AppColors.accent,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: AppColors.ink,
        collapsedTextColor: AppColors.ink,
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.muted,
        shape: Border(),
        collapsedShape: Border(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          iconSize: guide.iconSize,
          minimumSize: Size(64, guide.buttonHeight),
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          iconSize: guide.iconSize,
          minimumSize: Size(64, guide.buttonHeight),
          textStyle: base.textTheme.labelLarge?.merge(guide.buttonText),
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.selected
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppStyle.controlRadius),
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.selected,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
