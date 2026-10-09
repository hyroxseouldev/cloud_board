// Local-only preview of production timer widgets. No Firebase or session writes.
// fvm flutter run -d web-server -t tool/timer_ux_preview.dart --web-port 4173
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';

WorkoutModule timerPreviewModule() => WorkoutModule.empty('timer-preview')
    .copyWith(
      name: 'WAVE ZONE (CASH IN)',
      workSeconds: 800,
      restSeconds: 60,
      sets: 1,
      text: 'WAVE ZONE',
    );

void main() => runApp(TimerUxPreview(module: timerPreviewModule()));

class TimerUxPreview extends StatelessWidget {
  const TimerUxPreview({super.key, required this.module, this.localSource});
  final WorkoutModule module;
  final SlideEditorLocalDataSource? localSource;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      slideEditorRepositoryProvider.overrideWithValue(
        LocalSlideEditorRepository(localSource ?? SlideEditorLocalDataSource()),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cloudboard 타이머 개발 미리보기',
      theme: XonTheme.light,
      builder: XonTheme.responsiveBuilder,
      home: Builder(
        builder: (context) => SlideEditorScreen(
          guard: ExitGuard(),
          workoutId: 'timer-preview',
          moduleId: module.id,
          request: SlideEditRequest(
            module: module,
            onSave: (_) async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('미리보기에서만 저장했습니다.')));
              return true;
            },
          ),
        ),
      ),
    ),
  );
}
