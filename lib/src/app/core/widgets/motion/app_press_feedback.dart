import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Adds pointer feedback to an existing control without owning its action,
/// focus, semantics, keyboard activation, or hit target.
class AppPressFeedback extends HookWidget {
  const AppPressFeedback({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final pointer = useState<int?>(null);
    final reduced = AppMotion.reduced(context);
    useEffect(() {
      if (!enabled || reduced) pointer.value = null;
      return null;
    }, [enabled, reduced]);
    return Listener(
      onPointerDown: (event) {
        if (enabled && !reduced) pointer.value ??= event.pointer;
      },
      onPointerUp: (event) {
        if (pointer.value == event.pointer) pointer.value = null;
      },
      onPointerCancel: (event) {
        if (pointer.value == event.pointer) pointer.value = null;
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          end: pointer.value != null && enabled && !reduced ? .98 : 1,
        ),
        duration: AppMotion.duration(context, AppMotion.feedback),
        curve: AppMotion.curve,
        builder: (_, scale, child) => Transform.scale(
          scale: scale,
          transformHitTests: false,
          child: child,
        ),
        child: child,
      ),
    );
  }
}
