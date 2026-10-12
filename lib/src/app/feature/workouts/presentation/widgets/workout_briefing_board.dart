import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';

import 'dart:async';
import 'dart:math';

import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

// Broadcast content keeps its established palette and typography independently
// of the management application's theme.
abstract final class _DisplayBriefingStyle {
  static const ink = Color(0xFF202028);
  static const muted = Color(0xFF777683);
  static const accent = Color(0xFF77729D);
  static const surface = Color(0xFFF5F4F8);
  static const line = Color(0xFFE6E3EF);

  static TextStyle heading(double size) => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -size * .05,
    height: 1.25,
  );
}

/// Uses the same saved workout as playback: coaches never maintain a second board.
class WorkoutBriefingBoard extends HookWidget {
  const WorkoutBriefingBoard({
    super.key,
    required this.workout,
    this.displayMode = false,
    this.onStart,
    this.onExit,
    this.busy = false,
    this.error,
    this.startModule = 0,
    this.serverTimeOffsetMs = 0,
  });

  final Workout workout;
  final bool displayMode;
  final VoidCallback? onStart;
  final VoidCallback? onExit;
  final bool busy;
  final String? error;
  final int startModule;
  final int serverTimeOffsetMs;

  @override
  Widget build(BuildContext context) {
    final guide = AppStyle.of(context);
    final titleStyle = displayMode
        ? _DisplayBriefingStyle.heading(44)
        : guide.mainText;
    final brandStyle = displayMode
        ? _DisplayBriefingStyle.heading(24)
        : guide.subText3;
    final muted = displayMode ? _DisplayBriefingStyle.muted : AppColors.muted;
    final now = useState(DateTime.now());
    final pageCount = max(1, (workout.modules.length / 3).ceil());
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        now.value = DateTime.now();
      });
      return timer.cancel;
    }, const []);
    final page =
        ((now.value.millisecondsSinceEpoch + serverTimeOffsetMs) ~/ 12000) %
        pageCount;
    final date =
        '${now.value.year}.${now.value.month.toString().padLeft(2, '0')}.${now.value.day.toString().padLeft(2, '0')}';

    Widget footer() => Row(
      children: [
        Expanded(
          child: Text(
            workout.brandL,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: brandStyle,
          ),
        ),
        Expanded(
          child: Text(
            workout.brandR,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: brandStyle.copyWith(color: muted),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: displayMode ? Colors.white : AppColors.canvas,
      appBar: displayMode
          ? null
          : AppBar(
              title: const Text('수업 브리핑'),
              leading: IconButton(
                tooltip: '수업 종료',
                onPressed: busy ? null : onExit,
                icon: const Icon(Icons.close_rounded),
              ),
              backgroundColor: AppColors.canvas,
            ),
      body: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: displayMode ? _DisplayBriefingStyle.ink : AppColors.ink,
        ),
        child: displayMode
            ? MediaQuery.withNoTextScaling(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 1280,
                      height: 720,
                      child: Padding(
                        padding: const EdgeInsets.all(44),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '$date  ·  TODAY’S WORKOUT',
                              style: const TextStyle(
                                fontSize: 18,
                                color: _DisplayBriefingStyle.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              workout.name.isEmpty ? '오늘의 수업' : workout.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${workout.modules.length}개 운동 · 총 ${workoutDurationText(workout)}'
                              '${pageCount > 1 ? '  ·  ${page + 1}/$pageCount 페이지' : ''}',
                              style: brandStyle.copyWith(color: muted),
                            ),
                            const SizedBox(height: 28),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = page * 3;
                                    i <
                                        min(
                                          workout.modules.length,
                                          page * 3 + 3,
                                        );
                                    i++
                                  )
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right:
                                              i <
                                                  min(
                                                        workout.modules.length,
                                                        page * 3 + 3,
                                                      ) -
                                                      1
                                              ? 24
                                              : 0,
                                        ),
                                        child: _ModuleSummary(
                                          module: workout.modules[i],
                                          index: i,
                                          fit: true,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(
                              color: _DisplayBriefingStyle.line,
                              height: 28,
                            ),
                            footer(),
                            const SizedBox(height: 12),
                            const Text(
                              '수업 안내 · 강사의 시작 신호를 기다려 주세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: max(
                    24,
                    (MediaQuery.sizeOf(context).width - 1052) / 2,
                  ),
                  vertical: 24,
                ),
                children: [
                  Text(date, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(
                    workout.name.isEmpty ? '오늘의 수업' : workout.name,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${workout.modules.length}개 운동 · 총 ${workoutDurationText(workout)}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '수업 구성을 설명한 후 시작해 주세요.\n선택한 디스플레이에도 이 내용이 표시됩니다.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  if (startModule > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${startModule + 1}번 운동부터 시작합니다.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  for (var i = 0; i < workout.modules.length; i++) ...[
                    const SizedBox(height: 24),
                    _ModuleSummary(module: workout.modules[i], index: i),
                  ],
                  const Divider(height: 40),
                  footer(),
                ],
              ),
      ),
      bottomNavigationBar: displayMode
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onStart,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            workout.countdownSeconds == 0
                                ? '수업 시작'
                                : '수업 시작 · ${workout.countdownSeconds}초 카운트다운',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ModuleSummary extends StatelessWidget {
  const _ModuleSummary({
    required this.module,
    required this.index,
    this.fit = false,
  });
  final WorkoutModule module;
  final int index;
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final description = Text(
      module.text.isEmpty ? '운동 설명을 확인해 주세요.' : module.text,
      style: TextStyle(fontSize: fit ? 27 : 18, height: 1.45),
    );
    final titleStyle = fit
        ? _DisplayBriefingStyle.heading(28)
        : AppStyle.of(context).subText2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fit ? _DisplayBriefingStyle.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppStyle.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: fit ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${index + 1}. ${module.name.isEmpty ? '운동 ${index + 1}' : module.name}',
                maxLines: fit ? 2 : null,
                overflow: fit ? TextOverflow.ellipsis : TextOverflow.visible,
                style: titleStyle.copyWith(
                  color: fit ? _DisplayBriefingStyle.ink : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isContinuousTimer(module)
                  ? '${timerModeLabel(module.timerMode)} · ${moduleDurationText(module)}'
                  : hasRoundTiming(module)
                  ? '${module.rounds}라운드 · 총 ${moduleDurationText(module)}'
                  : module.intervalBlocks.length > 1
                  ? '${module.intervalBlocks.length}블록 · 총 ${moduleDurationText(module)}'
                  : module.workSeconds == 0
                  ? '휴식만 ${durationLabel(module.restSeconds)} × ${module.sets}회'
                  : '${durationLabel(module.workSeconds)} × ${module.sets}세트'
                        '${module.sets > 1 && module.restSeconds > 0 ? ' · 휴식 ${durationLabel(module.restSeconds)}' : ''}',
              style: TextStyle(
                color: fit ? _DisplayBriefingStyle.accent : AppColors.accent,
                fontSize: fit ? 20 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (fit)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: description,
                    ),
                  ),
                ),
              )
            else
              description,
          ],
        ),
      ),
    );
  }
}
