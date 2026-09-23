import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';

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
    this.onMinimize,
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
  final VoidCallback? onMinimize;
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
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 24,
                          8,
                          compact ? 12 : 24,
                          0,
                        ),
                        child: Row(
                          children: [
                            if (onLockChanged != null)
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: locked
                                      ? Semantics(
                                          button: true,
                                          label: '터치 잠금 해제. 길게 누르세요',
                                          child: InkWell(
                                            key: const ValueKey(
                                              'unlock-controls',
                                            ),
                                            onLongPress: () =>
                                                onLockChanged!(false),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_outline),
                                                  SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      '터치 잠금 중 · 길게 눌러 해제',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
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
                              )
                            else
                              const Spacer(),
                            if (onMinimize != null)
                              IconButton(
                                tooltip: '최소화',
                                onPressed: disabled ? null : onMinimize,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ),
                            TextButton(
                              onPressed: disabled ? null : onExit,
                              child: const Text('종료하기'),
                            ),
                          ],
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
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 24 : width * .1,
                        ),
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
                      SizedBox(height: tall ? 40 : 24),
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
class WorkoutControlTimeline extends HookWidget {
  const WorkoutControlTimeline({
    super.key,
    required this.durations,
    required this.currentModule,
    required this.elapsedMs,
    this.modules = const [],
    this.onSeek,
  });
  final List<int> durations;
  final List<WorkoutModule> modules;
  final int currentModule, elapsedMs;
  final Future<void> Function(int moduleIndex, int elapsedMs)? onSeek;

  @override
  Widget build(BuildContext context) {
    final candidate = useState<({int moduleIndex, int elapsedMs})?>(null);
    final pending = useState(false);
    final detailCanceled = useRef(false);
    final intervalLegends = useMemoized(
      () => List.generate(
        modules.length,
        (i) => _intervalLegend(
          modules[i],
          i < durations.length ? durations[i] * 1000 : 0,
        ),
      ),
      [modules],
    );
    final enabled = onSeek != null && !pending.value && durations.isNotEmpty;
    final minFlex = math.max(1, durations.fold<int>(0, (a, b) => a + b) ~/ 20);
    final flexes = durations.map((d) => math.max(minFlex, d)).toList();
    final total = flexes.fold<int>(0, (a, b) => a + b);
    Future<void> select(({int moduleIndex, int elapsedMs}) position) async {
      candidate.value = null;
      if (!enabled) return;
      pending.value = true;
      try {
        await onSeek!(position.moduleIndex, position.elapsedMs);
      } finally {
        if (context.mounted) pending.value = false;
      }
    }

    final track = LayoutBuilder(
      builder: (context, bounds) {
        ({int moduleIndex, int elapsedMs}) hit(double x) {
          var start = 0.0;
          for (var i = 0; i < flexes.length; i++) {
            final width = bounds.maxWidth * flexes[i] / total;
            if (x < start + width || i == flexes.length - 1) {
              // Use each rendered segment, including its minimum flex and
              // three-pixel inset, rather than the whole workout duration.
              final fraction = ((x - start - 3) / math.max(1, width - 6)).clamp(
                0.0,
                1.0,
              );
              final seconds = (fraction * durations[i]).round().clamp(
                0,
                math.max(0, durations[i] - 1),
              );
              return (moduleIndex: i, elapsedMs: seconds.toInt() * 1000);
            }
            start += width;
          }
          return (moduleIndex: 0, elapsedMs: 0);
        }

        return Listener(
          // Flutter may finish a recognized drag on pointer cancellation.
          // Clear its candidate before the gesture recognizer can commit it.
          onPointerCancel: (_) => candidate.value = null,
          child: GestureDetector(
            key: const ValueKey('class-timeline'),
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled
                ? (d) => unawaited(select(hit(d.localPosition.dx)))
                : null,
            onHorizontalDragStart: enabled
                ? (d) => candidate.value = hit(d.localPosition.dx)
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) => candidate.value = hit(d.localPosition.dx)
                : null,
            onHorizontalDragEnd: enabled
                ? (_) {
                    final position = candidate.value;
                    if (position != null) unawaited(select(position));
                  }
                : null,
            onHorizontalDragCancel: () => candidate.value = null,
            child: SizedBox(
              height: 48,
              child: Row(
                children: List.generate(
                  durations.length,
                  (index) => Expanded(
                    flex: flexes[index],
                    child: Semantics(
                      button: enabled,
                      selected:
                          index ==
                          (candidate.value?.moduleIndex ?? currentModule),
                      label: '슬라이드 ${index + 1} ${_title(index)} 재생 위치',
                      value: '${_time(durations[index] * 1000)} 길이',
                      onTap: enabled
                          ? () => unawaited(
                              select((moduleIndex: index, elapsedMs: 0)),
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final active =
                                candidate.value?.moduleIndex ?? currentModule;
                            final elapsed =
                                candidate.value?.elapsedMs ?? elapsedMs;
                            final progress = index < active
                                ? 1.0
                                : index > active
                                ? 0.0
                                : (elapsed /
                                          math.max(1, durations[index] * 1000))
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
                                if (index == active)
                                  Positioned(
                                    left: progress * constraints.maxWidth - 12,
                                    child: Icon(
                                      Icons.circle,
                                      size: 24,
                                      color: candidate.value == null
                                          ? AppColors.accent
                                          : AppColors.ink,
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
            ),
          ),
        );
      },
    );
    if (durations.isEmpty) return const SizedBox.shrink();
    final current = currentModule.clamp(0, durations.length - 1);
    final target = candidate.value;
    final active = (target?.moduleIndex ?? current).clamp(
      0,
      durations.length - 1,
    );
    final position = (target?.elapsedMs ?? elapsedMs).clamp(
      0,
      durations[active] * 1000,
    );
    final totalMs = durations.fold<int>(0, (a, b) => a + b) * 1000;
    final classElapsed =
        durations.take(current).fold<int>(0, (a, b) => a + b) * 1000 +
        elapsedMs;
    final frame = active < modules.length
        ? rehearsalFrame(modules[active], position)
        : null;
    final stage = frame == null
        ? ''
        : '블록 ${frame.blockIndex + 1} · ${frame.set}/${frame.totalSets}세트 · ${frame.isRest ? '휴식' : '운동'}';
    final maxPosition = math.max(0, durations[active] * 1000 - 1000).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '현재 슬라이드 ${current + 1}/${durations.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '전체 수업 ${_time(classElapsed)} / ${_time(totalMs)}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        track,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              durations.length,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: enabled
                      ? () => unawaited(
                          select((moduleIndex: index, elapsedMs: 0)),
                        )
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: index == current
                        ? AppColors.selected
                        : null,
                    foregroundColor: index == current
                        ? AppColors.accent
                        : AppColors.muted,
                  ),
                  child: Text('${index + 1}. ${_title(index)}'),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.selected.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  target == null
                      ? '현재 · ${_title(active)}'
                      : '이동할 위치 · 슬라이드 ${active + 1} · ${_title(active)}',
                  key: const ValueKey('timeline-destination'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (stage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(stage, key: const ValueKey('timeline-stage')),
                ],
                const SizedBox(height: 6),
                Text(
                  '슬라이드 내 ${_time(position)} / ${_time(durations[active] * 1000)}',
                ),
                if (frame != null)
                  Text(
                    '${frame.isRest ? '휴식' : '운동'} 남은 시간 ${_time(frame.remainingMs, roundUp: true)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                Listener(
                  onPointerCancel: (_) {
                    detailCanceled.value = true;
                    candidate.value = null;
                  },
                  child: Slider(
                    key: const ValueKey('slide-detail-timeline'),
                    min: 0,
                    max: math.max(1, maxPosition),
                    value: position.toDouble().clamp(0, maxPosition),
                    semanticFormatterCallback: (value) =>
                        '${_title(active)} 내 ${_time(value.round())}',
                    onChangeStart: enabled && maxPosition > 0
                        ? (_) => detailCanceled.value = false
                        : null,
                    onChanged: enabled && maxPosition > 0
                        ? (value) {
                            candidate.value = (
                              moduleIndex: active,
                              elapsedMs: (value / 1000).round() * 1000,
                            );
                          }
                        : null,
                    onChangeEnd: enabled && maxPosition > 0
                        ? (value) {
                            if (!detailCanceled.value) {
                              unawaited(
                                select((
                                  moduleIndex: active,
                                  elapsedMs: (value / 1000).round() * 1000,
                                )),
                              );
                            }
                          }
                        : null,
                  ),
                ),
                if (active < intervalLegends.length) intervalLegends[active],
                const SizedBox(height: 8),
                Text(
                  pending.value
                      ? '이동 중…'
                      : target != null
                      ? '손을 놓으면 이 위치로 이동합니다.'
                      : '막대를 터치하거나 드래그해 이동하세요.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _title(int index) =>
      index < modules.length && modules[index].name.trim().isNotEmpty
      ? modules[index].name
      : '슬라이드 ${index + 1}';

  static String _time(int milliseconds, {bool roundUp = false}) {
    final seconds = math.max(
      0,
      roundUp ? (milliseconds / 1000).ceil() : milliseconds ~/ 1000,
    );
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _intervalLegend(WorkoutModule module, int totalMs) {
    final labels = <Widget>[];
    var offset = 0;
    while (offset < totalMs) {
      final frame = rehearsalFrame(module, offset);
      if (frame.durationMs <= 0) break;
      labels.add(
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '${_time(offset)} ${frame.isRest ? '휴식' : '운동'} ${frame.set}세트',
            style: TextStyle(
              fontSize: 12,
              color: frame.isRest ? AppColors.muted : AppColors.accent,
            ),
          ),
        ),
      );
      final next = frame.startMs + frame.durationMs;
      if (next <= offset) break;
      offset = next;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: labels),
    );
  }
}
