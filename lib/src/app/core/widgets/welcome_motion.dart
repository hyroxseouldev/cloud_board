import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Animate a single retained subtree; forms are never duplicated during a step
/// transition. Changing field values does not restart the entrance animation.
class WelcomeMotion extends HookWidget {
  const WelcomeMotion({
    super.key,
    required this.child,
    this.motionKey,
    this.delayFraction = 0,
    this.horizontal = false,
    this.reverse = false,
  });
  final Widget child;
  final Object? motionKey;
  final double delayFraction;
  final bool horizontal, reverse;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final first = useRef(true);
    final previousKey = useRef(motionKey);
    final controller = useAnimationController(duration: AppMotion.introduction);
    useEffect(() {
      final animate = first.value || previousKey.value != motionKey;
      first.value = false;
      previousKey.value = motionKey;
      if (reduced) {
        controller.value = 1;
      } else if (animate) {
        controller.forward(from: 0);
      }
      return null;
    }, [motionKey, reduced]);
    final curved = controller.drive(
      CurveTween(curve: Interval(delayFraction, 1, curve: AppMotion.curve)),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: horizontal
              ? Offset(reverse ? -.035 : .035, 0)
              : const Offset(0, .025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
