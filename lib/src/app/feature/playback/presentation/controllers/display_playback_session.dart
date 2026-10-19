import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'display_playback_session.g.dart';

bool playbackAuthorizationFailed(Object? error) {
  final code = operationFailureCode(error);
  return code == 'permission-denied' || code == 'unauthenticated';
}

/// Rendering checkpoint only. ACKs and confirmed recovery must use the fresh
/// active-session stream, never this retained value. A scope change discards it.
@Riverpod(keepAlive: true)
class DisplayPlaybackSession extends _$DisplayPlaybackSession {
  @override
  PlaybackSession? build() {
    final owner = ref.watch(accountOwnerIdProvider);
    if (owner.isLoading || owner.hasError || owner.value == null) return null;
    final ownerId = owner.value!;
    PlaybackSession? owned(PlaybackSession? session) =>
        session?.ownerId == ownerId ? session : null;
    final recovery = ref.read(playbackRecoveryControllerProvider);
    final initial = ref.read(activePlaybackSessionProvider);
    var authorizationBlocked =
        (recovery.hasError && playbackAuthorizationFailed(recovery.error)) ||
        (initial.hasError && playbackAuthorizationFailed(initial.error));
    PlaybackSession? freshSession() {
      final current = ref.read(activePlaybackSessionProvider);
      return authorizationBlocked || current.isLoading || current.hasError
          ? null
          : owned(current.value);
    }

    ref.listen(activePlaybackSessionProvider, (_, next) {
      if (next.hasError) {
        if (playbackAuthorizationFailed(next.error)) {
          authorizationBlocked = true;
          state = null;
        }
      } else if (!next.isLoading && !authorizationBlocked) {
        // A confirmed null/completed/changed session replaces the checkpoint.
        state = owned(next.value);
      }
    });
    ref.listen(playbackRecoveryControllerProvider, (_, next) {
      if (next.hasError && playbackAuthorizationFailed(next.error)) {
        authorizationBlocked = true;
        state = null;
      } else if (!next.isLoading &&
          !next.hasError &&
          next.hasValue &&
          authorizationBlocked) {
        // Only confirmed recovery may reopen a rejected authorization scope.
        authorizationBlocked = false;
        state = freshSession();
      }
    });
    return freshSession();
  }
}
