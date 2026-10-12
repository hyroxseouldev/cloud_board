import 'package:flutter/material.dart';

/// Role-based v5 typography and controls, in logical pixels.
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({this.compact = true});

  final bool compact;
  static const fullWidth = 660.0;
  static const webPageMaxWidth = 1200.0;
  static const cardWidth = 540.0;
  static const cardMinHeight = 280.0;
  static const popupWidth = 420.0;
  static const popupMinHeight = 240.0;
  static const controlRadius = 12.0;
  static const cardRadius = 24.0;
  static const floatingRadius = 40.0;

  static AppStyle of(BuildContext context) =>
      Theme.of(context).extension<AppStyle>() ?? const AppStyle();

  double get buttonHeight => compact ? 48 : 52;
  double get primaryButtonHeight => compact ? 52 : 60;
  double get iconSize => compact ? 24 : 28;
  double get floatingSize => compact ? 56 : 64;

  TextStyle _heading(double tablet, double phone) {
    final size = compact ? phone : tablet;
    return TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: -size * .01,
      height: 1.3,
    );
  }

  TextStyle get mainText => _heading(32, 26);
  TextStyle get subText1 => _heading(26, 22);
  TextStyle get subText2 => _heading(22, 20);
  TextStyle get subText3 => _heading(20, 17);
  TextStyle get buttonText => _heading(17, 16).copyWith(letterSpacing: 0);

  @override
  AppStyle copyWith({bool? compact}) =>
      AppStyle(compact: compact ?? this.compact);

  @override
  AppStyle lerp(covariant AppStyle? other, double t) =>
      other == null || t < .5 ? this : other;
}
