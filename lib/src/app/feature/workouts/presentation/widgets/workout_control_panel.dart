import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';

/// The controller surface. Display playback keeps its full-screen canvas.
class WorkoutControlPanel extends HookWidget {
  const WorkoutControlPanel({
    super.key,
    required this.title,
    required this.moduleCount,
    required this.currentModule,
    required this.paused,
    required this.busy,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onExit,
    required this.onSelectModule,
    required this.previewBuilder,
    required this.timeline,
    this.message,
    this.locked = false,
    this.onLockChanged,
  });

  final String title;
  final int moduleCount, currentModule;
  final bool paused, busy;
  final VoidCallback onPrevious, onToggle, onNext, onExit;
  final Future<void> Function(int) onSelectModule;
  final Widget Function(BuildContext, int) previewBuilder;
  final Widget timeline;
  final String? message;
  final bool locked;
  final ValueChanged<bool>? onLockChanged;

  @override
  Widget build(BuildContext context) {
    final pages = usePageController(
      initialPage: currentModule,
      viewportFraction: .75,
    );
    final dragging = useRef(false);
    final pending = useState(false);
    final latestModule = useRef(currentModule)..value = currentModule;

    void restorePage() {
      if (!context.mounted || !pages.hasClients) return;
      if ((pages.page! - latestModule.value).abs() > .001) {
        pages.jumpToPage(latestModule.value);
      }
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!dragging.value && !pending.value) restorePage();
      });
      return null;
    }, [currentModule]);

    Future<void> select(int index) async {
      if (pending.value || busy || locked) {
        restorePage();
        return;
      }
      pending.value = true;
      try {
        await onSelectModule(index);
      } finally {
        if (context.mounted) {
          pending.value = false;
          // Read the confirmed position after the parent has rebuilt. A failed
          // remote command rolls the carousel back along with the player.
          WidgetsBinding.instance.addPostFrameCallback((_) => restorePage());
        }
      }
    }

    final disabled = busy || pending.value || locked;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final width = math.min(constraints.maxWidth, 960.0);
            final tall = constraints.maxHeight >= 850;
            final previewHeight = width * .75 * 9 / 16;
            return SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      if (onLockChanged != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: locked
                                ? Semantics(
                                    button: true,
                                    label: '터치 잠금 해제. 길게 누르세요',
                                    child: InkWell(
                                      key: const ValueKey('unlock-controls'),
                                      onLongPress: () => onLockChanged!(false),
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline),
                                            SizedBox(width: 8),
                                            Text('터치 잠금 중 · 길게 눌러 해제'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : TextButton.icon(
                                    onPressed: disabled
                                        ? null
                                        : () => onLockChanged!(true),
                                    icon: const Icon(Icons.lock_open),
                                    label: const Text('터치 잠금'),
                                  ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, tall ? 30 : 12, 24, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: disabled ? null : onExit,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: compact ? 16 : 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            child: const Text('종료하기'),
                          ),
                        ),
                      ),
                      SizedBox(height: tall ? 64 : 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontSize: compact ? 28 : 44),
                        ),
                      ),
                      SizedBox(height: tall ? 54 : 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '이전 운동',
                            onPressed: disabled ? null : onPrevious,
                            iconSize: compact ? 40 : 56,
                            color: AppColors.accent,
                            icon: const Icon(Icons.fast_rewind_rounded),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            tooltip: paused ? '재생' : '일시정지',
                            onPressed: disabled ? null : onToggle,
                            iconSize: compact ? 44 : 60,
                            color: AppColors.accent,
                            icon: Icon(
                              paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            tooltip: '다음 운동',
                            onPressed: disabled ? null : onNext,
                            iconSize: compact ? 40 : 56,
                            color: AppColors.accent,
                            icon: const Icon(Icons.fast_forward_rounded),
                          ),
                        ],
                      ),
                      SizedBox(height: tall ? 54 : 24),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: width * .15),
                        child: timeline,
                      ),
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                          child: Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      SizedBox(height: tall ? 100 : 40),
                      SizedBox(
                        height: previewHeight,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.depth != 0) return false;
                            if (notification is ScrollStartNotification &&
                                notification.dragDetails != null) {
                              dragging.value = true;
                            }
                            if (notification is ScrollEndNotification &&
                                dragging.value) {
                              dragging.value = false;
                              final index = pages.page!.round().clamp(
                                0,
                                moduleCount - 1,
                              );
                              if (index != latestModule.value) {
                                unawaited(select(index));
                              }
                            }
                            return false;
                          },
                          child: PageView.builder(
                            key: const ValueKey('workout-control-carousel'),
                            controller: pages,
                            physics: disabled
                                ? const NeverScrollableScrollPhysics()
                                : null,
                            itemCount: moduleCount,
                            itemBuilder: (context, index) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 12 : 20,
                              ),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: previewBuilder(context, index),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: List.generate(
                          moduleCount,
                          (index) => Semantics(
                            selected: index == currentModule,
                            label: '슬라이드 ${index + 1} / $moduleCount',
                            child: IconButton(
                              tooltip: '슬라이드 ${index + 1}로 이동',
                              onPressed: disabled
                                  ? null
                                  : () => unawaited(select(index)),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                              ),
                              iconSize: 8,
                              color: index == currentModule
                                  ? AppColors.ink
                                  : AppColors.line,
                              icon: const Icon(Icons.circle),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                        child: Text(
                          compact
                              ? '이미지를 좌우로 스와이프하면\n이전/다음 슬라이드 시작 위치로 이동합니다.'
                              : '이미지 스와이프 시 이전/다음 슬라이드 시작 위치로 넘어갑니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Width represents each slide's duration, including all work/rest intervals.
class WorkoutControlTimeline extends StatelessWidget {
  const WorkoutControlTimeline({
    super.key,
    required this.durations,
    required this.currentModule,
    required this.elapsedMs,
  });

  final List<int> durations;
  final int currentModule, elapsedMs;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '수업 진행',
    value: '슬라이드 ${currentModule + 1} / ${durations.length}',
    child: SizedBox(
      height: 36,
      child: Row(
        children: List.generate(
          durations.length,
          (index) => Expanded(
            // Keep very short slides visible beside long classes.
            flex: math.max(
              math.max(
                1,
                durations.fold<int>(0, (sum, item) => sum + item) ~/ 20,
              ),
              durations[index],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final progress = index < currentModule
                      ? 1.0
                      : index > currentModule
                      ? 0.0
                      : (elapsedMs / math.max(1, durations[index] * 1000))
                            .clamp(0.0, 1.0);
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          color: AppColors.accent,
                          backgroundColor: AppColors.selected,
                        ),
                      ),
                      if (index == currentModule)
                        Positioned(
                          left:
                              progress * math.max(0, constraints.maxWidth - 24),
                          child: const Icon(
                            Icons.circle,
                            size: 24,
                            color: AppColors.accent,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
