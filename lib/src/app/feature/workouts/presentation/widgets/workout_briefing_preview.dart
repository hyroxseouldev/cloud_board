import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';

/// The display's actual briefing canvas, framed by the application's preview UI.
class WorkoutBriefingPreview extends StatelessWidget {
  const WorkoutBriefingPreview({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('브리핑 미리보기'),
      leading: IconButton(
        tooltip: '미리보기 닫기',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              workout.modules.length > 3
                  ? '디스플레이 화면입니다. 슬라이드 3개씩 12초마다 자동으로 전환됩니다.'
                  : '디스플레이에 표시되는 수업 구성을 미리 확인하세요.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(AppStyle.cardRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppStyle.cardRadius,
                        ),
                        child: WorkoutBriefingBoard(
                          workout: workout,
                          displayMode: true,
                        ),
                      ),
                    ),
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
