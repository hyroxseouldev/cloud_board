import 'package:cloud_board/src/app/core/theme/app_motion.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

enum _LoadingPhase { waiting, visible, delayed }

/// Presentation timing only; the catalog controller remains the data owner.
({bool visible, bool delayed, Animation<double> reveal})
useWorkoutLoadingPresentation({required bool loading, required bool hasData}) {
  final phase = useState(_LoadingPhase.waiting);
  final shown = useRef(false);
  final reveal = useAnimationController(
    duration: AppMotion.stateChange,
    initialValue: 1,
  );
  useEffect(() {
    if (!loading) {
      if (hasData && shown.value) {
        reveal.forward(from: 0);
      } else {
        reveal.value = 1;
      }
      shown.value = false;
      phase.value = _LoadingPhase.waiting;
      return null;
    }
    phase.value = _LoadingPhase.waiting;
    reveal.value = 1;
    final appearance = Timer(const Duration(milliseconds: 150), () {
      shown.value = true;
      phase.value = _LoadingPhase.visible;
    });
    final delay = Timer(const Duration(seconds: 5), () {
      phase.value = _LoadingPhase.delayed;
    });
    return () {
      appearance.cancel();
      delay.cancel();
    };
  }, [loading, hasData]);
  return (
    visible: loading && phase.value != _LoadingPhase.waiting,
    delayed: loading && phase.value == _LoadingPhase.delayed,
    reveal: reveal,
  );
}

/// Keep the status slot after loading so the first row never jumps upward.
class WorkoutLoadingStatus extends StatelessWidget {
  const WorkoutLoadingStatus({
    super.key,
    required this.visible,
    required this.delayed,
  });

  final bool visible;
  final bool delayed;

  @override
  Widget build(BuildContext context) {
    final label = delayed ? '연결이 조금 지연되고 있어요' : '워크아웃을 불러오는 중';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Visibility(
        visible: visible,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: label,
          child: ExcludeSemantics(
            child: Text(
              label,
              key: const ValueKey('workout-loading-status'),
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Both real and placeholder tablet rows use the same grid geometry.
SliverGridDelegateWithFixedCrossAxisCount workoutListGridDelegate(
  BuildContext context,
  double width,
) {
  final scaler = MediaQuery.textScalerOf(context);
  final minWidth = 440 + math.max(0, scaler.scale(16) - 16) * 10;
  final textHeight =
      (scaler.scale(16) * 1.3).ceilToDouble() * 2 +
      4 +
      (scaler.scale(12) * 1.3).ceilToDouble() +
      4 +
      (scaler.scale(13) * 1.3).ceilToDouble();
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: ((width + 16) / (minWidth + 16)).floor().clamp(1, 2),
    mainAxisExtent: 32 + math.max(72, textHeight),
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  );
}

class WorkoutListSkeleton extends HookWidget {
  const WorkoutListSkeleton({super.key, required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = AppMotion.reduced(context);
    final shimmer = useAnimationController(duration: AppMotion.shimmer);
    useEffect(() {
      if (reducedMotion) {
        shimmer.stop();
      } else {
        shimmer.repeat();
      }
      return null;
    }, [reducedMotion]);

    Widget row() => ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: _SkeletonRow(
            framed: !mobile,
            shimmer: shimmer,
            reducedMotion: reducedMotion,
          ),
        ),
      ),
    );

    if (mobile) {
      return SliverList.list(
        key: const ValueKey('workout-list-skeleton'),
        children: [
          for (var i = 0; i < 2; i++) ...[row(), const Divider(height: 1)],
        ],
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid.builder(
        key: const ValueKey('workout-list-skeleton'),
        gridDelegate: workoutListGridDelegate(
          context,
          constraints.crossAxisExtent,
        ),
        itemCount: 2,
        itemBuilder: (_, _) => row(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.framed,
    required this.shimmer,
    required this.reducedMotion,
  });

  final bool framed;
  final Animation<double> shimmer;
  final bool reducedMotion;
  static const _base = Color(0xFFF0EEF5);
  static const _highlight = Color(0xFFF8F7FB);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final contents = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: framed ? 16 : 0,
        vertical: framed ? 16 : 14,
      ),
      child: Row(
        children: [
          _block(width: framed ? 72 : 60, height: framed ? 72 : 60, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(0.70, scaler.scale(16) * 1.3),
                const SizedBox(height: 4),
                _bar(0.46, scaler.scale(12) * 1.3),
                const SizedBox(height: 4),
                _bar(0.23, scaler.scale(13) * 1.3),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _block(width: 44, height: 44, radius: 12),
          const SizedBox(width: 8),
          _block(width: 44, height: 44, radius: 12),
        ],
      ),
    );
    final animated = reducedMotion
        ? contents
        : AnimatedBuilder(
            animation: shimmer,
            child: contents,
            builder: (_, child) => ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(-3 + shimmer.value * 4, 0),
                end: Alignment(-1 + shimmer.value * 4, 0),
                colors: const [_base, _highlight, _base],
              ).createShader(bounds),
              child: child,
            ),
          );
    return framed
        ? DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: animated,
          )
        : animated;
  }

  Widget _bar(double fraction, double height) => SizedBox(
    height: height,
    child: Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: _block(height: height * 0.6, radius: 6),
      ),
    ),
  );

  Widget _block({
    double? width,
    required double height,
    required double radius,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: _base,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class WorkoutListLoadError extends StatelessWidget {
  const WorkoutListLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '워크아웃을 불러오지 못했어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    ),
  );
}
