import 'package:flutter/material.dart';

/// Tablet style guide in logical pixels, adapted for phone layouts.
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({this.compact = true});

  final bool compact;
  static const fullWidth = 660.0;
  static const cardWidth = 540.0;
  static const cardMinHeight = 280.0;
  static const popupWidth = 420.0;
  static const popupMinHeight = 240.0;
  static const controlRadius = 12.0;
  static const cardRadius = 24.0;
  static const floatingRadius = 40.0;

  static AppStyle of(BuildContext context) =>
      Theme.of(context).extension<AppStyle>() ?? const AppStyle();

  double get buttonHeight => compact ? 48 : 60;
  double get primaryButtonHeight => compact ? 60 : 80;
  double get iconSize => compact ? 24 : 30;
  double get floatingSize => compact ? 60 : 100;

  TextStyle _bold(double tablet, double phone) {
    final size = compact ? phone : tablet;
    return TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -size * .05,
      height: 1.25,
    );
  }

  TextStyle get mainText => _bold(44, 28);
  TextStyle get subText1 => _bold(32, 24);
  TextStyle get subText2 => _bold(28, 20);
  TextStyle get subText3 => _bold(24, 18);
  TextStyle get buttonText => _bold(24, 16);

  @override
  AppStyle copyWith({bool? compact}) =>
      AppStyle(compact: compact ?? this.compact);

  @override
  AppStyle lerp(covariant AppStyle? other, double t) =>
      other == null || t < .5 ? this : other;
}
