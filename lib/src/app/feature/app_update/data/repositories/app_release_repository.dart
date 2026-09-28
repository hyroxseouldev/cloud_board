import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/repositories/app_release_repository.dart';
import 'package:cloud_board/src/app/feature/app_update/data/datasources/app_release_data_source.dart';
import 'package:cloud_board/src/app/feature/app_update/data/models/app_release_model.dart';
part 'app_release_repository.g.dart';

class FirebaseAppReleaseRepository implements AppReleaseRepository {
  FirebaseAppReleaseRepository(this.source);
  final AppReleaseDataSource source;
  @override
  Future<AppRelease?> load(String platform) async {
    try {
      final data = await source.load(platform);
      return data == null ? null : AppReleaseModel.fromJson(data).toEntity();
    } catch (_) {
      return null;
    } // Offline/malformed config must never lock the app.
  }

  @override
  Future<int> installedBuild() => source.installedBuild();
  @override
  Future<int> dismissedUntil(int build) => source.dismissedUntil(build);
  @override
  Future<void> dismiss(int build, int until) => source.dismiss(build, until);
}

@riverpod
AppReleaseRepository appReleaseRepository(Ref ref) =>
    FirebaseAppReleaseRepository(AppReleaseDataSource());
