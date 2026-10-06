import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test(
    'save keeps rows visible, uses prepared values, and makes no full read',
    () async {
      final repo = _Repository();
      final c = ProviderContainer(
        overrides: [slideEditorRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final provider = slideTemplatesControllerProvider('u');
      c.listen(provider, (_, _) {});
      c.listen(slideTemplateWritesProvider('u'), (_, _) {});
      await c.read(provider.future);
      final before = repo.items.single;
      final save = c
          .read(provider.notifier)
          .updateTemplate(
            before.copyWith(name: 'edited', imageSource: 'inline'),
          );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(provider).isLoading, isFalse);
      expect(c.read(provider).requireValue.single, before);
      expect(c.read(slideTemplateWritesProvider('u')), {'a'});
      expect(await c.read(provider.notifier).remove('a'), isFalse);
      final remote = WorkoutModule.empty('remote');
      repo.events.add([before, remote]);
      await Future<void>.delayed(Duration.zero);
      repo.gate.complete();
      expect(await save, isTrue);
      expect(repo.reads, 0);
      final values = c.read(provider).requireValue;
      expect(values.map((v) => v.id), containsAll(['a', 'remote']));
      expect(
        values.firstWhere((v) => v.id == 'a').imageSource,
        'https://uploaded',
      );
      expect(c.read(slideTemplateWritesProvider('u')), isEmpty);
    },
  );

  test(
    'accepted local save never overwrites a newer same-item stream update',
    () {
      final before = WorkoutModule.empty('a');
      final saved = before.copyWith(name: 'my accepted edit');
      final newer = before.copyWith(name: 'newer remote edit');
      expect(mergeSavedTemplates([before], [saved], [newer]), [newer]);
      expect(mergeSavedTemplates([before], [], [newer]), [newer]);
      expect(mergeSavedTemplates([before], [], [before]), isEmpty);
    },
  );

  test(
    'a rejected write retains the draft and reloads authoritative values once',
    () async {
      final repo = _Repository()..fail = true;
      final c = ProviderContainer(
        overrides: [slideEditorRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final provider = slideTemplatesControllerProvider('u');
      c.listen(provider, (_, _) {});
      await c.read(provider.future);
      final edited = repo.items.single.copyWith(name: 'draft');
      final saving = c.read(provider.notifier).updateTemplate(edited);
      repo.gate.complete();
      expect(await saving, isFalse);
      expect(repo.reads, 1);
      expect(c.read(provider.notifier).pendingDraft, edited);
      expect(c.read(provider).requireValue, repo.items);
    },
  );
}

class _Repository extends LocalSlideEditorRepository {
  _Repository() : super(SlideEditorLocalDataSource());
  final items = [WorkoutModule.empty('a')];
  final events = StreamController<List<WorkoutModule>>();
  final gate = Completer<void>();
  int reads = 0;
  bool fail = false;
  @override
  Stream<List<WorkoutModule>> watchTemplates(String scope) async* {
    yield items;
    yield* events.stream;
  }

  @override
  Future<List<WorkoutModule>> loadTemplates(String scope) async {
    reads++;
    return items;
  }

  @override
  Future<List<WorkoutModule>> saveTemplates(
    String scope,
    List<WorkoutModule> templates, {
    List<WorkoutModule>? previous,
  }) async {
    await gate.future;
    if (fail) throw StateError('conflict');
    return [
      for (final item in templates)
        item.copyWith(imageSource: 'https://uploaded'),
    ];
  }
}
