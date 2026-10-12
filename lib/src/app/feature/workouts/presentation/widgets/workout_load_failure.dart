import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';

class WorkoutLoadFailure extends StatelessWidget {
  const WorkoutLoadFailure({
    super.key,
    required this.error,
    required this.onRetry,
    this.stack,
  });

  final Object? error;
  final StackTrace? stack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            workoutErrorMessage(
              error,
              fallback: '워크아웃을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
          ErrorDetailsButton(
            error: error,
            stack: stack,
            action: 'workout.detail',
          ),
        ],
      ),
    ),
  );
}
