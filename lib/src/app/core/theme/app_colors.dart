import 'package:flutter/material.dart';

/// STA-121 v5 Oat Sage. App chrome only; class/TV content keeps its own palette.
abstract final class AppColors {
  static const canvas = Color(0xFFF7F5EF);
  static const surface = Color(0xFFFFFDF8);
  static const surfaceAccent = Color(0xFFE3EAE2);
  static const navigation = Color(0xFFF0F0E8);
  static const ink = Color(0xFF2B332E);
  // Slightly deepen the v5 candidate (#657066) for small text on sage surfaces.
  static const muted = Color(0xFF616B63);
  static const secondaryText = muted;
  static const accent = Color(0xFF526B60);
  static const onAccent = Colors.white;
  static const selected = surfaceAccent;
  static const line = Color(0xFFDEE3D9);
  // Interactive outlines are stronger than decorative list dividers.
  static const controlBorder = Color(0xFF7A887C);
  static const dialog = surface;
  static const brandBoardDark = accent;
  static const brandBoardLight = Color(0xFFB2C1AE);
  static const brandHighlight = surfaceAccent;
}
