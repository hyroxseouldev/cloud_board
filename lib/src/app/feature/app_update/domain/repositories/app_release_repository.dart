import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';

abstract interface class AppReleaseRepository {
  Future<AppRelease?> load(String platform);
  Future<int> installedBuild();
  Future<int> dismissedUntil(int build);
  Future<void> dismiss(int build, int until);
}
