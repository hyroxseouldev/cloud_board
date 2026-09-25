import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_interval_slider_track.dart';

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
    this.progress,
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
  final Widget? progress;
  final String? message;
  final VoidCallback? onMinimize;
  final bool locked;
  final ValueChanged<bool>? onLockChanged;

  @override
  Widget build(BuildContext context) {
    final pages = usePageController(
      initialPage: currentModule,
      viewportFraction: .9,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: onLockChanged == null
                              ? const SizedBox.shrink()
                              : locked
                              ? Semantics(
                                  button: true,
                                  label: '터치 잠금 해제. 길게 누르세요',
                                  child: InkWell(
                                    key: const ValueKey('unlock-controls'),
                                    onLongPress: () => onLockChanged!(false),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text('길게 눌러 해제'),
                                    ),
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: disabled
                                      ? null
                                      : () => onLockChanged!(true),
                                  icon: const Icon(Icons.lock_open, size: 20),
                                  label: const Text('터치 잠금'),
                                ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: disabled ? null : onExit,
                        icon: const Icon(Icons.stop_circle_outlined, size: 20),
                        label: const Text('종료하기'),
                      ),
                      if (onMinimize != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '최소화',
                          onPressed: disabled ? null : onMinimize,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: progress!,
                  ),
                const Divider(height: 1),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bounds) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      // Keep the whole controller visible on ordinary portrait
                      // phones. Small landscape screens / large accessibility
                      // text may scroll the body; progress and tips stay pinned.
                      final previewHeight = math.min(
                        bounds.maxWidth * .9 * 9 / 16,
                        math.max(100.0, bounds.maxHeight - 280 * textScale),
                      );
                      return SingleChildScrollView(
                        key: const ValueKey('control-body'),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, bounds.maxHeight - 24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: '이전 운동',
                                    onPressed: disabled ? null : onPrevious,
                                    iconSize: 36,
                                    color: AppColors.accent,
                                    icon: const Icon(Icons.fast_rewind_rounded),
                                  ),
                                  const SizedBox(width: 24),
                                  IconButton(
                                    tooltip: paused ? '재생' : '일시정지',
                                    onPressed: disabled ? null : onToggle,
                                    iconSize: 40,
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
                                    iconSize: 36,
                                    color: AppColors.accent,
                                    icon: const Icon(
                                      Icons.fast_forward_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              if (message != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    8,
                                  ),
                                  child: Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: previewHeight,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification.depth != 0) return false;
                                    if (notification
                                            is ScrollStartNotification &&
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
                                    key: const ValueKey(
                                      'workout-control-carousel',
                                    ),
                                    controller: pages,
                                    physics: disabled
                                        ? const NeverScrollableScrollPhysics()
                                        : null,
                                    itemCount: moduleCount,
                                    itemBuilder: (context, index) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Center(
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: previewBuilder(
                                              context,
                                              index,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: timeline,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  key: ValueKey('control-tips'),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    '막대 터치·드래그: 구간 이동\n이미지 좌우 스와이프: 이전/다음 슬라이드 시작으로 이동',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum WorkoutTimelineSection { all, progress, detail }

/// Overall progress uses real duration; detail seeking remains within one slide.
class WorkoutControlTimeline extends HookWidget {
  const WorkoutControlTimeline({
    super.key,
    required this.durations,
    required this.currentModule,
    required this.elapsedMs,
    this.modules = const [],
    this.onSeek,
    this.section = WorkoutTimelineSection.all,
  });
  final List<int> durations;
  final List<WorkoutModule> modules;
  final int currentModule, elapsedMs;
  final Future<void> Function(int moduleIndex, int elapsedMs)? onSeek;
  final WorkoutTimelineSection section;

  @override
  Widget build(BuildContext context) {
    final candidate = useState<({int moduleIndex, int elapsedMs})?>(null);
    final pending = useState(false);
    final detailCanceled = useRef(false);
    final intervalSegments = useMemoized(
      () => modules.map(workoutIntervalSegments).toList(),
      [modules],
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
        (durations.take(active).fold<int>(0, (a, b) => a + b) * 1000 + position)
            .clamp(0, math.max(0, totalMs))
            .toInt();
    final enabled = onSeek != null && !pending.value && totalMs > 0;

    Future<void> select(({int moduleIndex, int elapsedMs}) destination) async {
      candidate.value = null;
      if (!enabled || pending.value) return;
      pending.value = true;
      try {
        await onSeek!(destination.moduleIndex, destination.elapsedMs);
      } finally {
        if (context.mounted) pending.value = false;
      }
    }

    ({int moduleIndex, int elapsedMs}) atTime(int timeMs) {
      var remaining = timeMs.clamp(0, math.max(0, totalMs - 1000)).toInt();
      for (var i = 0; i < durations.length; i++) {
        final length = durations[i] * 1000;
        if (remaining < length || i == durations.length - 1) {
          return (
            moduleIndex: i,
            elapsedMs: remaining.clamp(0, math.max(0, length - 1000)).toInt(),
          );
        }
        remaining -= length;
      }
      return (moduleIndex: 0, elapsedMs: 0);
    }

    final progress = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              '${active + 1}/${durations.length}',
              semanticsLabel: '현재 슬라이드 ${active + 1}/${durations.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              '${_time(classElapsed)} / ${_time(totalMs)}',
              semanticsLabel:
                  '전체 수업 ${_time(classElapsed)} / ${_time(totalMs)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, bounds) {
            ({int moduleIndex, int elapsedMs}) hit(double x) => atTime(
              (((x / math.max(1, bounds.maxWidth)).clamp(0.0, 1.0) *
                          totalMs /
                          1000)
                      .round()) *
                  1000,
            );
            return Semantics(
              label: '전체 수업 재생 위치',
              value:
                  '${_time(classElapsed)} / ${_time(totalMs)}, 슬라이드 ${active + 1}',
              increasedValue: enabled
                  ? _time(
                      math.min(
                        classElapsed + 10000,
                        math.max(0, totalMs - 1000),
                      ),
                    )
                  : null,
              decreasedValue: enabled
                  ? _time(math.max(0, classElapsed - 10000))
                  : null,
              onIncrease: enabled
                  ? () => unawaited(select(atTime(classElapsed + 10000)))
                  : null,
              onDecrease: enabled
                  ? () => unawaited(select(atTime(classElapsed - 10000)))
                  : null,
              child: Listener(
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
                          final destination = candidate.value;
                          if (destination != null) {
                            unawaited(select(destination));
                          }
                        }
                      : null,
                  onHorizontalDragCancel: () => candidate.value = null,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: classElapsed / math.max(1, totalMs),
                          minHeight: 4,
                          stopIndicatorRadius: 0,
                          trackGap: 0,
                          color: AppColors.accent,
                          backgroundColor: AppColors.selected,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
    if (section == WorkoutTimelineSection.progress) return progress;

    final frame = active < modules.length
        ? rehearsalFrame(modules[active], position)
        : null;
    final stage = frame == null
        ? ''
        : '${frame.set}/${frame.totalSets} · ${frame.isRest ? '휴식' : '운동'}';
    final maxPosition = math.max(0, durations[active] * 1000 - 1000).toDouble();
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PopupMenuButton<int>(
                tooltip: '슬라이드 선택',
                popUpAnimationStyle: AnimationStyle.noAnimation,
                enabled: enabled,
                initialValue: current,
                onSelected: (index) =>
                    unawaited(select((moduleIndex: index, elapsedMs: 0))),
                itemBuilder: (_) => List.generate(
                  durations.length,
                  (i) => PopupMenuItem<int>(
                    value: i,
                    child: Text('${i + 1}. ${_title(i)}'),
                  ),
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          target == null
                              ? _title(active)
                              : '이동할 위치 · 슬라이드 ${active + 1} · ${_title(active)}',
                          key: const ValueKey('timeline-destination'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_time(position)} / ${_time(durations[active] * 1000)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            if (stage.isNotEmpty)
              Semantics(
                label:
                    '${frame!.totalSets}세트 중 ${frame.set}세트, ${frame.isRest ? '휴식' : '운동'}',
                excludeSemantics: true,
                child: Text(
                  stage,
                  key: const ValueKey('timeline-stage'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (frame != null)
              Text(
                '${_time(frame.remainingMs, roundUp: true)} 남음',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
          ],
        ),
        Listener(
          onPointerCancel: (_) {
            detailCanceled.value = true;
            candidate.value = null;
          },
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              trackShape:
                  active < intervalSegments.length &&
                      intervalSegments[active].isNotEmpty
                  ? WorkoutIntervalSliderTrack(
                      segments: intervalSegments[active],
                      positionMs: position,
                      maxMs: maxPosition,
                    )
                  : const RoundedRectSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              key: const ValueKey('slide-detail-timeline'),
              min: 0,
              max: math.max(1, maxPosition),
              value: position.toDouble().clamp(0, maxPosition),
              semanticFormatterCallback: (value) {
                final destination = active < modules.length
                    ? rehearsalFrame(modules[active], value.round())
                    : null;
                return '${_title(active)} 내 ${_time(value.round())}'
                    '${destination == null ? '' : ', ${destination.set}세트 ${destination.isRest ? '휴식' : '운동'}'}';
              },
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
        ),
        if (pending.value || target != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              pending.value ? '이동 중…' : '손을 놓으면 이 위치로 이동합니다.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
      ],
    );
    return section == WorkoutTimelineSection.detail
        ? detail
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [progress, detail],
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
}
