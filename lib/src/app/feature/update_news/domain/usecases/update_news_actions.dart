import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/update_news/data/repositories/update_news_repository_impl.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/repositories/update_news_repository.dart';
part 'update_news_actions.g.dart';

class UpdateNewsActions {
  const UpdateNewsActions(this.repository);
  final UpdateNewsRepository repository;

  Future<UpdateNewsState> load(String uid) async {
    final installed = await repository.installed();
    final notes =
        (await repository.load())
            .where((note) => note.availableFor(installed))
            .toList()
          ..sort((a, b) {
            final date = b.date.compareTo(a.date);
            if (date != 0) return date;
            final build = compareReleaseNumbers(
              b.builds[installed.platform]!,
              a.builds[installed.platform]!,
            )!;
            return build != 0 ? build : b.id.compareTo(a.id);
          });
    return UpdateNewsState(
      notes: notes,
      readIds: await repository.readIds(uid),
    );
  }

  Future<void> markRead(String uid, Set<String> ids) =>
      repository.saveReadIds(uid, ids);
}

@riverpod
UpdateNewsActions updateNewsActions(Ref ref) =>
    UpdateNewsActions(ref.watch(updateNewsRepositoryProvider));
