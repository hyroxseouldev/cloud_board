import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_raster_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_raster_controller.dart';

import 'support/ai_raster_fakes.dart';

void main() {
  Future<ProviderContainer> setup(FakeRasterRepository repository) async {
    final container = ProviderContainer(
      overrides: [aiRasterRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.listen(aiRasterControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test(
    'opening/editing/grouping manually never generates or encodes a PNG',
    () async {
      final repository = FakeRasterRepository();
      final container = await setup(repository);
      final controller = container.read(aiRasterControllerProvider.notifier);
      controller.raw(rasterTestDraft.rawWod);
      controller.edit(
        container
            .read(aiRasterControllerProvider)
            .draft
            .copyWith(brief: '3개 그룹, 글자를 작게'),
      );
      controller.applyRequestedSettings();
      final draft = container.read(aiRasterControllerProvider).draft;
      expect(draft.groups.length, 3);
      expect(draft.bodyFontSize, 32);
      expect(
        draft.groups.expand((g) => g.lines),
        rasterTestDraft.groups.single.lines,
      );
      expect(rasterDraftError(draft), isNull);
      expect(repository.generations, 0);
      expect(repository.organizations, 0);
      expect(repository.additions, 0);
    },
  );
  test('invalid local draft never allocates a pending job', () async {
    final repository = FakeRasterRepository();
    final container = await setup(repository);
    await container.read(aiRasterControllerProvider.notifier).generate();
    expect(container.read(aiRasterControllerProvider).pendingRequestId, isNull);
    expect(container.read(aiRasterControllerProvider).error, isNotNull);
    expect(repository.generations, 0);
  });
  test('double tap generates once, preserves edits in flight, adds reviewed snapshot only, undo restores', () async {
    final repository = FakeRasterRepository()
      ..recent = rasterTestJob('previous')
      ..generation = Completer<AiRasterReply>();
    final container = await setup(repository);
    final controller = container.read(aiRasterControllerProvider.notifier);
    final pending = controller.generate();
    await controller.generate();
    controller.raw('새 운동 15회');
    controller.newRequest();
    controller.undo();
    expect(repository.generations, 1);
    expect(
      container.read(aiRasterControllerProvider).pendingRequestId,
      repository.lastRequestId,
    );
    repository.generation!.complete((
      job: rasterTestJob(repository.lastRequestId!),
      remaining: 29,
      limit: 30,
    ));
    await pending;
    expect(container.read(aiRasterControllerProvider).draft.rawWod, '새 운동 15회');
    expect(
      container.read(aiRasterControllerProvider).result!.draft,
      rasterTestDraft,
    );
    await controller.add();
    expect(repository.added!.draft, rasterTestDraft);
    controller.undo();
    expect(
      container.read(aiRasterControllerProvider).result!.requestId,
      'previous',
    );
    expect(repository.generations, 1);
  });
  test('timeout retains input/result and retry is same-id status with zero extra generation', () async {
    final repository = FakeRasterRepository()
      ..recent = rasterTestJob('previous')
      ..generateFailure = const AiSlidesFailure(
        'timeout',
        code: 'deadline-exceeded',
      );
    final container = await setup(repository);
    final controller = container.read(aiRasterControllerProvider.notifier);
    await controller.generate();
    final pending = container.read(aiRasterControllerProvider);
    expect(pending.result!.requestId, 'previous');
    expect(pending.draft, rasterTestDraft);
    expect(pending.pendingStatus, 'uncertain');
    expect(pending.pendingRequestId, repository.lastRequestId);
    await controller.refreshResult();
    expect(repository.statuses, 1);
    expect(repository.generations, 1);
    expect(repository.lastStatusId, repository.lastRequestId);
  });
  test('late AI grouping cannot replace newer user/IME input', () async {
    final repository = FakeRasterRepository()
      ..grouping = Completer<AiRasterGroups>();
    final container = await setup(repository);
    final controller = container.read(aiRasterControllerProvider.notifier);
    controller.edit(rasterTestDraft);
    final pending = controller.organize();
    controller.raw('새 운동 19.5 kg');
    repository.grouping!.complete((
      groups: rasterTestDraft.groups,
      remaining: 29,
      limit: 30,
    ));
    await pending;
    expect(
      container.read(aiRasterControllerProvider).draft.rawWod,
      '새 운동 19.5 kg',
    );
    expect(container.read(aiRasterControllerProvider).remaining, 29);
  });
  test(
    'account/center switch drops old async completion and private history',
    () async {
      final first = FakeRasterRepository()
        ..recent = rasterTestJob('old')
        ..generation = Completer<AiRasterReply>();
      final container = await setup(first);
      final pending = container
          .read(aiRasterControllerProvider.notifier)
          .generate();
      final second = FakeRasterRepository()
        ..brand = rasterTestBrand.copyWith(key: 'other-center');
      container.updateOverrides([
        aiRasterRepositoryProvider.overrideWithValue(second),
      ]);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      first.generation!.complete((
        job: rasterTestJob('late'),
        remaining: 29,
        limit: 30,
      ));
      await pending;
      expect(
        container.read(aiRasterControllerProvider).brand!.key,
        'other-center',
      );
      expect(container.read(aiRasterControllerProvider).result, isNull);
      expect(container.read(aiRasterControllerProvider).history, isEmpty);
    },
  );
  test('reopen uncertain request keeps last completed result; permission loss clears pixels', () async {
    final repository = FakeRasterRepository()
      ..recent = rasterTestJob('pending').copyWith(status: 'uncertain')
      ..previous = rasterTestJob('completed')
      ..statusFailure = const AiSlidesFailure(
        'revoked',
        code: 'permission-denied',
      );
    final container = await setup(repository);
    expect(
      container.read(aiRasterControllerProvider).result!.requestId,
      'completed',
    );
    await container.read(aiRasterControllerProvider.notifier).refreshResult();
    expect(container.read(aiRasterControllerProvider).brand, isNull);
    expect(container.read(aiRasterControllerProvider).result, isNull);
    expect(container.read(aiRasterControllerProvider).history, isEmpty);
  });
}
