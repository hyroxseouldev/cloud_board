import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Reveals one retained subtree. Never duplicates forms, focus or providers.
/// Only a semantic state change (not an ordinary rebuild) restarts the reveal.
class AppContentTransition extends HookWidget {
  const AppContentTransition({
    super.key,
    required this.transitionKey,
    required this.child,
    this.animateOnMount = false,
  });

  final Object? transitionKey;
  final Widget child;
  final bool animateOnMount;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final first = useRef(true);
    final previousKey = useRef(transitionKey);
    final controller = useAnimationController(
      duration: AppMotion.stateChange,
      initialValue: 1,
    );
    useEffect(() {
      final animate = first.value
          ? animateOnMount
          : previousKey.value != transitionKey;
      first.value = false;
      previousKey.value = transitionKey;
      if (reduced || !animate) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
      return null;
    }, [transitionKey, reduced]);
    return FadeTransition(
      // Keep the new content readable and interactive from its first frame.
      opacity: controller.drive(
        Tween(begin: .55, end: 1.0).chain(CurveTween(curve: AppMotion.curve)),
      ),
      child: child,
    );
  }
}
