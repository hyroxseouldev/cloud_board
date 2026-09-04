import 'package:flutter/material.dart';

abstract final class XonColors {
  static const black = Color(0xFF050505);
  static const cobalt = Color(0xFF0047FF);
  static const pale = Color(0xFFF2F2F2);
  static const line = Color(0xFFD9D9D9);
  static const muted = Color(0xFF777777);
}

abstract final class XonTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: XonColors.cobalt,
        primary: XonColors.cobalt,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: XonColors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Pretendard',
        bodyColor: XonColors.black,
        displayColor: XonColors.black,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: XonColors.line, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: XonColors.line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: XonColors.black, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
