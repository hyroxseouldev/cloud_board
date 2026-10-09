import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

class AiSlidesPreview extends StatelessWidget {
  const AiSlidesPreview({
    super.key,
    required this.module,
    this.compact = false,
  });
  final WorkoutModule module;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final preview = Semantics(
      button: true,
      label: '수업 이미지 확대',
      child: InkWell(
        key: const ValueKey('ai-slides-preview-expand'),
        onTap: () => showAiSlidesPreview(context, module),
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: WorkoutSlidePreview(module: module, isRest: false),
        ),
      ),
    );
    if (compact) return Center(child: preview);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        preview,
        const SizedBox(height: 8),
        Text(
          module.showTimer ? '실제 타이머 위치를 함께 확인할 수 있어요.' : '수업 내용과 배치를 확인해 주세요.',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

Future<void> showAiSlidesPreview(BuildContext context, WorkoutModule module) =>
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('슬라이드 미리보기')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: WorkoutSlidePreview(module: module, isRest: false),
              ),
            ),
          ),
        ),
      ),
    );
