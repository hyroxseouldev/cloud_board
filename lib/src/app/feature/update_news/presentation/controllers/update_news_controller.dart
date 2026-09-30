import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';

import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/usecases/update_news_actions.dart';
part 'update_news_controller.g.dart';

@riverpod
class UpdateNewsController extends _$UpdateNewsController {
  Future<void> _writes = Future.value();
  int _generation = 0;
  @override
  Future<UpdateNewsState> build() async {
    ++_generation;
    final uid = ref.watch(authStateProvider.select((value) => value.value?.id));
    if (uid == null) return const UpdateNewsState();
    return ref.watch(updateNewsActionsProvider).load(uid);
  }

  Future<void> markRead(String id) {
    final uid = ref.read(authStateProvider).value?.id;
    final generation = _generation;
    final actions = ref.read(updateNewsActionsProvider);
    final operation = _writes.then((_) async {
      if (!ref.mounted || generation != _generation || uid == null) return;
      final current = state.value;
      if (current == null ||
          current.readIds.contains(id) ||
          !current.notes.any((note) => note.id == id)) {
        return;
      }
      final ids = {...current.readIds, id};
      await actions.markRead(uid, ids);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(current.copyWith(readIds: ids));
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}
