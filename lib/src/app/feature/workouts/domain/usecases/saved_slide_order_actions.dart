import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/saved_slide_order_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/saved_slide_order.dart';

part 'saved_slide_order_actions.g.dart';

class SavedSlideOrderActions {
  SavedSlideOrderActions(this.repository);
  final SavedSlideOrderRepository repository;
  Stream<List<String>> watch(String scope) => repository.watch(scope);
  Future<List<String>> load(String scope) => repository.load(scope);
  Future<List<String>> reconcile(
    String scope,
    List<String> ids, {
    SavedSlideMove? move,
  }) => repository.reconcile(scope, ids, move: move);
}

@riverpod
SavedSlideOrderActions savedSlideOrderActions(Ref ref) =>
    SavedSlideOrderActions(ref.watch(savedSlideOrderRepositoryProvider));
