import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';

abstract interface class UpdateNewsRepository {
  Future<List<UpdateNews>> load();
  Future<InstalledRelease> installed();
  Future<Set<String>> readIds(String uid);
  Future<void> saveReadIds(String uid, Set<String> ids);
}
