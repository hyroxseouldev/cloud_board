import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_raster_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/slide_studio_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

import 'support/slide_studio_fakes.dart';
import 'support/ai_raster_fakes.dart';

void main() {
  Future<ProviderContainer> setup(
    FakeStudioRepository repository, {
    String Function()? owner,
  }) async {
    final container = ProviderContainer(
      overrides: [
        aiSlidesOwnerIdProvider.overrideWith(
          (_) => owner?.call() ?? 'local-owner',
        ),
        centerSlideCatalogScopeProvider.overrideWithValue(null),
        slideStudioActionsProvider.overrideWithValue(
          SlideStudioActions(repository),
        ),
        aiRasterActionsProvider.overrideWithValue(
          AiRasterActions(FakeRasterRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(slideStudioControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  const source = 'Row 1,000 m\nDB Squat 22.5 kg × 12\n휴식 60초';
  test('opening, input, reference and design choices never generate or encode; local result uses selected theme', () async {
    final repository = FakeStudioRepository();
    final c = await setup(repository);
    final controller = c.read(slideStudioControllerProvider.notifier);
    controller.reference(Uint8List.fromList([1, 2, 3]));
    controller.select(aiSlideDesignCatalog[3]);
    controller.edit(
      c.read(slideStudioControllerProvider).input.copyWith(raw: source),
    );
    expect(repository.generations, 0);
    expect(repository.prepares, 0);
    await controller.generate();
    final result = c.read(slideStudioControllerProvider).result!;
    expect(result.draft!.lines.join('\n'), source);
    expect(
      result.draft!.designStyle,
      aiSlideDesignCatalog[3].theme.designStyle,
    );
    expect(result.draft!.designSubtitle, isEmpty);
    expect(result.savedModule, isNull);
    expect(repository.generations, 0);
    expect(repository.prepares, 0);
  });
  test('dirty input keeps prior result, blocks saving/adding and restores with undo', () async {
    final repository = FakeStudioRepository();
    final c = await setup(repository);
    final controller = c.read(slideStudioControllerProvider.notifier);
    controller.edit(
      c.read(slideStudioControllerProvider).input.copyWith(raw: source),
    );
    await controller.generate();
    final first = c.read(slideStudioControllerProvider).result;
    controller.edit(
      c.read(slideStudioControllerProvider).input.copyWith(raw: 'Run 200m'),
    );
    expect(c.read(slideStudioControllerProvider).result, first);
    expect(c.read(slideStudioControllerProvider).dirty, isTrue);
    await controller.save();
    expect(await controller.add(), isNull);
    expect(repository.prepares, 0);
    await controller.generate();
    controller.undo();
    expect(c.read(slideStudioControllerProvider).input.raw, source);
    expect(c.read(slideStudioControllerProvider).result, first);
  });
  test(
    'double taps and late completion never overwrite newer input or result',
    () async {
      final repository = FakeStudioRepository()
        ..generation = Completer<StudioOperation>();
      final c = await setup(repository),
          controller = c.read(slideStudioControllerProvider.notifier);
      controller.edit(
        c.read(slideStudioControllerProvider).input.copyWith(raw: source),
      );
      await controller.generate();
      final previous = c.read(slideStudioControllerProvider).result;
      controller.edit(
        c
            .read(slideStudioControllerProvider)
            .input
            .copyWith(mode: StudioMode.organize),
      );
      final pending = controller.generate();
      await Future<void>.delayed(Duration.zero);
      await controller.generate();
      controller.edit(
        c.read(slideStudioControllerProvider).input.copyWith(raw: '새 운동 9회'),
      );
      repository.generation!.complete(
        StudioOperation(requestId: repository.lastId!, status: 'completed'),
      );
      await pending;
      expect(repository.generations, 1);
      expect(c.read(slideStudioControllerProvider).input.raw, '새 운동 9회');
      expect(c.read(slideStudioControllerProvider).result, previous);
      expect(c.read(slideStudioControllerProvider).history, isNotEmpty);
    },
  );
  test('unknown transport retry reads same request ID without another provider call', () async {
    final repository = FakeStudioRepository()
      ..generationFailure = const AiSlidesFailure(
        'timeout',
        code: 'unavailable',
      );
    final c = await setup(repository),
        controller = c.read(slideStudioControllerProvider.notifier);
    controller.edit(
      c
          .read(slideStudioControllerProvider)
          .input
          .copyWith(raw: source, mode: StudioMode.organize),
    );
    await controller.generate();
    final request = c.read(slideStudioControllerProvider).pendingId;
    expect(request, isNotNull);
    await controller.generate();
    await controller.retry();
    expect(repository.generations, 1);
    expect(repository.statuses, 1);
    expect(repository.lastStatusId, request);
    expect(c.read(slideStudioControllerProvider).result!.input.raw, source);
  });
  test('an uncertain repeated request blocks saving and adding the earlier clean result', () async {
    final repository = FakeStudioRepository();
    final c = await setup(repository);
    final controller = c.read(slideStudioControllerProvider.notifier);
    controller.edit(
      c
          .read(slideStudioControllerProvider)
          .input
          .copyWith(raw: source, mode: StudioMode.organize),
    );
    await controller.generate();
    final previous = c.read(slideStudioControllerProvider).result;
    repository.generationFailure = const AiSlidesFailure(
      'timeout',
      code: 'unavailable',
    );
    await controller.generate();
    expect(c.read(slideStudioControllerProvider).dirty, isFalse);
    expect(c.read(slideStudioControllerProvider).pendingId, isNotNull);
    await controller.save();
    expect(await controller.add(), isNull);
    expect(repository.prepares, 0);
    expect(c.read(slideStudioControllerProvider).result, previous);
    expect(c.read(slideStudioControllerProvider).leaving, isFalse);
  });
  test('save failure preserves result and ID; success only after acknowledgment; add has no save dependency', () async {
    final repository = FakeStudioRepository()
      ..saveFailure = Exception('offline');
    final c = await setup(repository),
        controller = c.read(slideStudioControllerProvider.notifier);
    controller.edit(
      c.read(slideStudioControllerProvider).input.copyWith(raw: source),
    );
    await controller.generate();
    final result = c.read(slideStudioControllerProvider).result!;
    await controller.save();
    expect(c.read(slideStudioControllerProvider).result!.savedModule, isNull);
    repository.saveFailure = null;
    await controller.save();
    await controller.save();
    expect(repository.saved.keys, [result.id]);
    expect(repository.saves, 2);
    expect(
      c.read(slideStudioControllerProvider).result!.savedModule!.id,
      result.id,
    );
    expect((await controller.add())!.id, result.id);
    expect(repository.generations, 0);
  });
  test('usage refresh failure preserves last real values and never invents zero or unlimited', () async {
    final repository = FakeStudioRepository();
    final c = await setup(repository);
    final controller = c.read(slideStudioControllerProvider.notifier);
    await controller.refreshUsage();
    repository.usageFailure = Exception('offline');
    await controller.refreshUsage();
    final state = c.read(slideStudioControllerProvider);
    expect(state.usage!.remaining, 8);
    expect(state.usage!.unlimited, isFalse);
    expect(state.usage!.lastInputTokens, isNull);
    expect(state.usageError, isNotNull);
  });
  test('account lifetime invalidates pending work even for A-B-A', () async {
    final repository = FakeStudioRepository()
      ..generation = Completer<StudioOperation>();
    var ownerId = 'local-owner';
    final c = await setup(repository, owner: () => ownerId),
        controller = c.read(slideStudioControllerProvider.notifier);
    controller.edit(
      c
          .read(slideStudioControllerProvider)
          .input
          .copyWith(raw: source, mode: StudioMode.organize),
    );
    final pending = controller.generate();
    await Future<void>.delayed(Duration.zero);
    ownerId = 'other';
    c.invalidate(aiSlidesOwnerIdProvider);
    await c.pump();
    ownerId = 'local-owner';
    c.invalidate(aiSlidesOwnerIdProvider);
    await c.pump();
    repository.generation!.complete(
      StudioOperation(requestId: repository.lastId!, status: 'completed'),
    );
    await pending;
    expect(c.read(slideStudioControllerProvider).result, isNull);
    expect(c.read(slideStudioControllerProvider).input.raw, isEmpty);
  });
}
