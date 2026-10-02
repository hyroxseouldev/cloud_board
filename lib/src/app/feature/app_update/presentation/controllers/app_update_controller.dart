import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/usecases/check_app_update.dart';
part 'app_update_controller.g.dart';

@Riverpod(keepAlive: true)
class AppUpdateController extends _$AppUpdateController {
  @override
  Future<({AppRelease release, UpdateKind kind})?> build() async {
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      return null;
    }
    return ref
        .watch(checkAppUpdateProvider)
        .call(defaultTargetPlatform.name.toLowerCase());
  }

  Future<void> checkNow() async {
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform) ||
        state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(checkAppUpdateProvider)
          .call(defaultTargetPlatform.name.toLowerCase(), ignoreSnooze: true),
    );
  }

  Future<void> later() async {
    final update = state.value;
    if (update == null || update.kind == UpdateKind.required) return;
    // Local persistence failing should not force an optional update.
    state = const AsyncData(null);
    try {
      await ref
          .read(checkAppUpdateProvider)
          .dismiss(update.release.latestBuild);
    } catch (_) {}
  }
}
