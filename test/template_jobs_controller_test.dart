import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/template_jobs_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/template_jobs_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/slide_studio_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

import 'support/template_jobs_fakes.dart';
import 'support/slide_studio_fakes.dart';

void main() {
  Future<ProviderContainer> setup(
    FakeTemplateJobsRepository jobs,
    FakeStudioRepository studio, {
    String Function()? owner,
  }) async {
    final c = ProviderContainer(
      overrides: [
        aiSlidesOwnerIdProvider.overrideWith((_) => owner?.call() ?? 'owner'),
        centerSlideCatalogScopeProvider.overrideWithValue(
          const CenterSlideCatalogScope(
            ownerId: 'owner',
            centerId: 'local-center',
          ),
        ),
        centerSlideCatalogProvider.overrideWith(
          (_) => Stream.value(
            CenterSlideCatalog(
              revision: 1,
              centerId: 'local-center',
              centerName: 'local',
              templates: [templateTestDesign],
            ),
          ),
        ),
        templateJobsActionsProvider.overrideWithValue(
          TemplateJobsActions(jobs),
        ),
        slideStudioActionsProvider.overrideWithValue(
          SlideStudioActions(studio),
        ),
      ],
    );
    c.listen(templateJobsControllerProvider, (_, _) {});
    c.listen(slideStudioControllerProvider, (_, _) {});
    c.listen(centerSlideCatalogProvider, (_, _) {});
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  final input = StudioInput(
    design: templateTestDesign,
    subtitle: '운동 안내',
    raw: 'Row 1,000 m\nSquat 22.5kg × 12',
  );
  test('enqueue releases UI on receipt, double tap once, selected completion reads once without local layout/render', () async {
    final jobs = FakeTemplateJobsRepository()
      ..enqueueWait = Completer<TemplateJobsReply>();
    final studio = FakeStudioRepository();
    final c = await setup(jobs, studio);
    final controller = c.read(templateJobsControllerProvider.notifier);
    final pending = controller.enqueue(input.copyWith(raw: 'long raw\n' * 200));
    await Future<void>.delayed(Duration.zero);
    await controller.enqueue(input);
    expect(jobs.enqueues, 1);
    expect(c.read(templateJobsControllerProvider).submitting, true);
    final id = jobs.lastId!;
    jobs.enqueueWait!.complete(
      TemplateJobsReply([templateTestJob(id)], templateTestUsage),
    );
    await pending;
    expect(c.read(templateJobsControllerProvider).submitting, false);
    expect(c.read(templateJobsControllerProvider).jobs.single.inProgress, true);
    expect(studio.validations, 0);
    expect(studio.prepares, 0);
    await controller.enqueue(input);
    expect(
      jobs.enqueues,
      1,
    ); // An accepted pending job cannot be double submitted.
    jobs.events.add([
      templateTestJob('unrelated', status: 'complete', time: 3),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(jobs.assets, 0);
    jobs.events.add([templateTestJob(id, status: 'complete', time: 2)]);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(slideStudioControllerProvider).result, isNull);
    expect(jobs.assets, 1);
    expect(c.read(templateJobsControllerProvider).currentPng, templateTestPng);
    await controller.refresh();
    expect(jobs.assets, 1);
  });
  test('new creation rejects blank guidance without changing optional completed-job contracts', () async {
    final jobs = FakeTemplateJobsRepository(), studio = FakeStudioRepository();
    final c = await setup(jobs, studio);
    await c
        .read(templateJobsControllerProvider.notifier)
        .enqueue(input.copyWith(subtitle: '  '));
    expect(jobs.enqueues, 0);
    expect(c.read(templateJobsControllerProvider).error, contains('운동 안내'));
    final editor = c.read(slideStudioControllerProvider.notifier);
    final legacy = templateTestJob(
      'legacy',
      status: 'complete',
    ).copyWith(subtitle: '');
    final png = await c
        .read(templateJobsControllerProvider.notifier)
        .open(legacy);
    editor.openTemplateResult(legacy, png!);
    expect(
      c.read(slideStudioControllerProvider).result!.input.subtitle,
      isEmpty,
    );
  });
  test('asset failure is latched, explicit retry reads once and cleared selection drops a late result', () async {
    final jobs = FakeTemplateJobsRepository()
      ..jobs = [templateTestJob('current', status: 'complete')]
      ..assetFailure = const AiSlidesFailure('offline');
    final c = await setup(jobs, FakeStudioRepository());
    final controller = c.read(templateJobsControllerProvider.notifier);
    controller.selectCurrent('current');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(templateJobsControllerProvider).currentAssetError, 'offline');
    await controller.refresh();
    expect(jobs.assets, 1);
    jobs.assetFailure = null;
    jobs.assetWait = Completer();
    final retry = controller.retryCurrentAsset();
    await Future<void>.delayed(Duration.zero);
    controller.selectCurrent(
      null,
    ); // A new basic result/undo supersedes the job.
    jobs.assetWait!.complete(templateTestPng);
    await retry;
    expect(c.read(templateJobsControllerProvider).currentPng, isNull);
    expect(c.read(templateJobsControllerProvider).currentRequestId, isNull);
    expect(jobs.assets, 2);
  });
  test('revoked account discards private image completions', () async {
    final jobs = FakeTemplateJobsRepository()
      ..jobs = [templateTestJob('current', status: 'complete')]
      ..assetWait = Completer();
    final c = await setup(jobs, FakeStudioRepository());
    c.read(templateJobsControllerProvider.notifier).selectCurrent('current');
    await Future<void>.delayed(Duration.zero);
    jobs.events.addError(
      const AiSlidesFailure('revoked', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    jobs.assetWait!.complete(templateTestPng);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(templateJobsControllerProvider).currentPng, isNull);
    expect(c.read(templateJobsControllerProvider).authorityDenied, true);
  });
  test('complete server PNG opens without overwriting draft and uses existing image save/add without local render', () async {
    final jobs = FakeTemplateJobsRepository(), studio = FakeStudioRepository();
    final c = await setup(jobs, studio),
        editor = c.read(slideStudioControllerProvider.notifier);
    editor.edit(input.copyWith(raw: 'new unsent input'));
    final job = templateTestJob('complete', status: 'complete');
    final bytes = await c
        .read(templateJobsControllerProvider.notifier)
        .open(job);
    editor.openTemplateResult(job, bytes!);
    expect(c.read(slideStudioControllerProvider).input.raw, 'new unsent input');
    await editor.save();
    expect(studio.saves, 1);
    expect(studio.prepares, 0);
    expect(studio.validations, 0);
    final module = await editor.add();
    expect(module!.imageSource, startsWith('data:image/png;base64,'));
    expect(module.text, job.rawWod);
    expect(module.showTimer, false);
    expect(module.appearance.showBody, false);
  });
  test('re-entry lists jobs and unresolved requests without generating, explicit recovery then safe retry only', () async {
    final jobs = FakeTemplateJobsRepository()
      ..unresolved = true
      ..jobs = [templateTestJob('older', status: 'failed')];
    final c = await setup(jobs, FakeStudioRepository());
    final controller = c.read(templateJobsControllerProvider.notifier);
    expect(
      c.read(templateJobsControllerProvider).jobs.single.requestId,
      'older',
    );
    expect(c.read(templateJobsControllerProvider).unresolved, true);
    expect(jobs.enqueues, 0);
    expect(jobs.recoveries, 0);
    await controller.enqueue(input);
    expect(jobs.enqueues, 0);
    await controller.recover();
    expect(jobs.recoveries, 1);
    await controller.retry(jobs.jobs.single);
    expect(jobs.retries, 0);
    await controller.retry(jobs.jobs.single.copyWith(retryable: true));
    expect(jobs.retries, 1);
    expect(jobs.lastId, isNot('older'));
  });
  test(
    'cursor preserves newer snapshot and adds older page without loading PNG',
    () async {
      final jobs = FakeTemplateJobsRepository()
        ..nextCursor = 'cursor'
        ..jobs = [templateTestJob('recent', time: 20)]
        ..older = [templateTestJob('old')];
      final c = await setup(jobs, FakeStudioRepository());
      jobs.events.add([
        templateTestJob('recent', time: 30, status: 'complete'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await c.read(templateJobsControllerProvider.notifier).loadMore();
      expect(jobs.before, 'cursor');
      expect(
        c.read(templateJobsControllerProvider).jobs.map((j) => j.requestId),
        ['recent', 'old'],
      );
      expect(c.read(templateJobsControllerProvider).jobs.first.complete, true);
      expect(jobs.assets, 0);
    },
  );
  test('account switch drops late enqueue reply and permission error clears private jobs', () async {
    var owner = 'owner';
    final jobs = FakeTemplateJobsRepository()
      ..enqueueWait = Completer<TemplateJobsReply>();
    final c = await setup(jobs, FakeStudioRepository(), owner: () => owner);
    final future = c
        .read(templateJobsControllerProvider.notifier)
        .enqueue(input);
    await Future<void>.delayed(Duration.zero);
    owner = 'other';
    c.invalidate(aiSlidesOwnerIdProvider);
    await c.pump();
    jobs.enqueueWait!.complete(
      TemplateJobsReply([templateTestJob('old-account')], templateTestUsage),
    );
    await future;
    expect(c.read(templateJobsControllerProvider).jobs, isEmpty);
    jobs.events.add([templateTestJob('private')]);
    await Future<void>.delayed(Duration.zero);
    jobs.events.addError(
      const AiSlidesFailure('revoked', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.read(templateJobsControllerProvider).jobs, isEmpty);
    expect(c.read(templateJobsControllerProvider).authorityDenied, true);
  });
}
