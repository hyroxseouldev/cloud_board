import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/repositories/app_release_repository.dart';
import 'package:cloud_board/src/app/feature/app_update/data/repositories/app_release_repository.dart';
part 'check_app_update.g.dart';

class CheckAppUpdate {
  const CheckAppUpdate(this.repository);
  final AppReleaseRepository repository;
  Future<({AppRelease release, UpdateKind kind})?> call(
    String platform, {
    bool ignoreSnooze = false,
  }) async {
    try {
      final release = await repository.load(platform);
      if (release == null) return null;
      final kind = release.evaluate(
        platform: platform,
        installedBuild: await repository.installedBuild(),
      );
      if (kind == UpdateKind.none) return null;
      if (!ignoreSnooze &&
          kind == UpdateKind.optional &&
          await repository.dismissedUntil(release.latestBuild) >
              DateTime.now().millisecondsSinceEpoch) {
        return null;
      }
      return (release: release, kind: kind);
    } catch (_) {
      return null;
    }
  }

  Future<void> dismiss(int build) => repository.dismiss(
    build,
    DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
  );
}

@riverpod
CheckAppUpdate checkAppUpdate(Ref ref) =>
    CheckAppUpdate(ref.watch(appReleaseRepositoryProvider));
