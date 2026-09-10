import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';

class _MemorySource extends SlideEditorLocalDataSource {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (fail) throw StateError('storage unavailable');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  test('custom slide chips persist all content per account and preserve data on failure', () async {
    final source = _MemorySource();
    final repository = LocalSlideEditorRepository(source);
    ProviderContainer container() => ProviderContainer(
      overrides: [slideEditorRepositoryProvider.overrideWithValue(repository)],
    );
    final provider = slideTemplatesControllerProvider('coach-a');
    final first = container();
    final subscription = first.listen(provider, (_, _) {});
    await first.read(provider.future);
    final module = WorkoutModule.empty('original').copyWith(
      name: '원본',
      text: '스쿼트 10회',
      imageSource: 'https://example.com/image.png',
      workSeconds: 180,
      restSeconds: 30,
      sets: 3,
      showTimer: false,
      appearance: const SlideAppearance(timerY: .6, ringWidth: 20),
      intervalBlocks: [
        const WorkoutIntervalBlock(
          id: 'block',
          workSeconds: 40,
          restSeconds: 20,
          sets: 4,
        ),
      ],
    );
    expect(await first.read(provider.notifier).save(module, '나의 운동'), isTrue);
    final saved = first.read(provider).requireValue.single;
    expect(saved.id, isNot(module.id));
    expect(saved.copyWith(id: module.id, name: module.name), module);
    subscription.close();
    first.dispose();

    final reopened = container();
    addTearDown(reopened.dispose);
    reopened.listen(provider, (_, _) {});
    expect(await reopened.read(provider.future), [saved]);
    expect(await repository.loadTemplates('coach-b'), isEmpty);
    expect(await repository.loadStyles('coach-a'), isEmpty);
    source.fail = true;
    expect(await reopened.read(provider.notifier).save(module, '실패'), isFalse);
    expect(await reopened.read(provider.notifier).remove(saved.id), isFalse);
    expect(reopened.read(provider).requireValue, [saved]);
    source.fail = false;
    expect(await reopened.read(provider.notifier).remove(saved.id), isTrue);
    expect(await repository.loadTemplates('coach-a'), isEmpty);
  });
}
