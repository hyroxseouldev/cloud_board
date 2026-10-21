import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/display_playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_retention.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'display_image_retention.g.dart';

/// Survives a display widget remount, but never an account/binding scope.
@Riverpod(keepAlive: true)
WorkoutImageRetention displayImageRetention(Ref ref) {
  ref.watch(accountOwnerIdProvider);
  final cache = WorkoutImageRetention();
  ref.onDispose(cache.dispose);
  void update(PlaybackSession? session) {
    if (session == null || session.status == PlaybackStatus.completed) {
      cache.clear();
    } else {
      cache.activate(
        session.id,
        sources: workoutImageWindow(
          session.workout,
          count: session.workout.modules.length,
          includeCountdown: true,
        ),
      );
    }
  }

  ref.listen(displayPlaybackSessionProvider, (_, next) => update(next));
  final session = ref.read(displayPlaybackSessionProvider);
  if (session != null) update(session);
  return cache;
}
