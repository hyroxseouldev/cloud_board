import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';

/// The original local mark, gently breathing while the app prepares.
/// Only the composited image changes; the loading announcement stays stable.
class SoftRhythmLoadingMark extends HookWidget {
  const SoftRhythmLoadingMark({super.key, this.size = 128});

  final double size;
  static const cycle = Duration(milliseconds: 1800);
  static const minimumScale = .97;
  static const minimumOpacity = .80;

  @override
  Widget build(BuildContext context) {
    final lifecycle = useAppLifecycleState();
    final animate =
        !AppMotion.reduced(context) &&
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final controller = useAnimationController(
      duration: cycle ~/ 2,
      initialValue: 1,
    );
    useEffect(() {
      if (animate) {
        controller.repeat(reverse: true);
      } else {
        controller.stop();
        controller.value = 1;
      }
      // useAnimationController owns disposal. A keyed effect cleanup can run
      // after its replacement effect and would stop the newly resumed ticker.
      return null;
    }, [animate, controller]);
    final breath = controller.drive(CurveTween(curve: Curves.easeInOut));
    return Semantics(
      label: '앱 준비 중',
      liveRegion: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: Tween<double>(
              begin: minimumOpacity,
              end: 1,
            ).animate(breath),
            child: ScaleTransition(
              scale: Tween<double>(begin: minimumScale, end: 1).animate(breath),
              child: SoftRhythmMark(size: size),
            ),
          ),
        ),
      ),
    );
  }
}
