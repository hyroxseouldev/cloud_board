import 'package:flutter/material.dart';

/// Presentation timings. Business actions never wait for these durations.
abstract final class AppMotion {
  static const feedback = Duration(milliseconds: 120);
  static const stateChange = Duration(milliseconds: 180);
  static const selection = Duration(milliseconds: 220);
  static const layout = Duration(milliseconds: 240);
  static const introduction = Duration(milliseconds: 420);
  static const shimmer = Duration(milliseconds: 1300);
  static const recovery = Duration(milliseconds: 1200);
  static const slideshow = Duration(milliseconds: 600);
  static const boardShift = Duration(seconds: 2);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;

  static AnimationStyle sheet(BuildContext context) => AnimationStyle(
    duration: duration(context, layout),
    reverseDuration: duration(context, stateChange),
  );
}
