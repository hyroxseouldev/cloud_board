import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/usecases/library_folder_actions.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
part 'library_folder_controller.g.dart';

@riverpod
Stream<List<String>> libraryFolders(Ref ref) {
  final owner = ref.watch(authStateProvider).value?.id;
  if (owner == null) return Stream.value(const []);
  return ref.watch(libraryFolderActionsProvider).watch(owner);
}

@riverpod
class LibraryFolderController extends _$LibraryFolderController {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  Future<bool> change(String action, String name, {String? newName}) async {
    if (state.isLoading) return false;
    final actions = ref.read(libraryFolderActionsProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => switch (action) {
        'create' => actions.create(name),
        'rename' => actions.rename(name, newName!),
        'remove' => actions.remove(name),
        _ => throw ArgumentError.value(action),
      },
    );
    if (!ref.mounted) return false;
    state = result;
    if (result.hasError) {
      ref
          .read(errorReporterProvider)
          .capture(
            result.error!,
            result.stackTrace!,
            action: 'library.folder.$action',
          );
    }
    return !result.hasError;
  }
}
