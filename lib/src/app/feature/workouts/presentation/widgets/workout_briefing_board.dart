import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

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
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
          ),
        ),
        Expanded(
          child: Text(
            workout.brandR,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: displayMode
          ? null
          : AppBar(
              title: const Text('수업 브리핑'),
              leading: IconButton(
                tooltip: '수업 종료',
                onPressed: busy ? null : onExit,
                icon: const Icon(Icons.close_rounded),
              ),
              backgroundColor: const Color(0xFFF7F5EF),
            ),
      body: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF171717)),
        child: displayMode
            ? Center(
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
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            workout.name.isEmpty ? '오늘의 수업' : workout.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${workout.modules.length}개 운동 · 총 ${durationLabel(workoutDuration(workout))}'
                            '${pageCount > 1 ? '  ·  ${page + 1}/$pageCount 페이지' : ''}',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 28),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var i = page * 3;
                                  i < min(workout.modules.length, page * 3 + 3);
                                  i++
                                )
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 24),
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
                          const Divider(color: Colors.black54, height: 28),
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
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(date, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(
                    workout.name.isEmpty ? '오늘의 수업' : workout.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${workout.modules.length}개 운동 · 총 ${durationLabel(workoutDuration(workout))}',
                    style: const TextStyle(fontSize: 18),
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
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('수업 시작 · 3초 카운트다운'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fit ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          color: const Color(0xFF171717),
          padding: const EdgeInsets.all(10),
          child: Text(
            '${index + 1}. ${module.name.isEmpty ? '운동 ${index + 1}' : module.name}',
            maxLines: fit ? 2 : null,
            overflow: fit ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              color: Colors.white,
              fontSize: fit ? 25 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${durationLabel(module.workSeconds)} × ${module.sets}세트'
          '${module.sets > 1 && module.restSeconds > 0 ? ' · 휴식 ${durationLabel(module.restSeconds)}' : ''}',
          style: TextStyle(
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
    );
  }
}
