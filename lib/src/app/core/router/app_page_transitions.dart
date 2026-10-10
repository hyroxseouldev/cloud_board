import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Used on web only. Native platforms retain Flutter's navigation gestures and
/// platform transitions, including interactive/predictive back.
class AppWebPageTransitions extends PageTransitionsBuilder {
  const AppWebPageTransitions();

  @override
  Duration get transitionDuration => AppMotion.stateChange;

  @override
  Duration get reverseTransitionDuration => AppMotion.stateChange;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: AppMotion.reduced(context)
        ? const AlwaysStoppedAnimation(1)
        : animation.drive(CurveTween(curve: AppMotion.curve)),
    child: child,
  );
}
