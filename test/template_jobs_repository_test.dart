import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/template_jobs_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/template_job_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/template_jobs_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';

import 'support/template_jobs_fakes.dart';

const usage = {
  'allowed': true,
  'enabled': true,
  'used': 2,
  'remaining': 8,
  'limit': 10,
};
Map<String, dynamic> row(String id, {String status = 'pending'}) => {
  'requestId': id,
  'status': status,
  'title': '센터 결과',
  'subtitle': '안내',
  'rawWod': 'Row 1,000m\nSquat 22.5kg × 12',
  'designId': 'center-original',
  'designName': '센터 승인 원본',
  'createdAtMs': 1,
  'updatedAtMs': 1,
  if (status == 'complete')
    'artifact': {
      'sha256': templateTestJob(id, status: status).sha256,
      'width': 1920,
      'height': 1080,
    },
};

class Source implements TemplateJobsDataSource {
  final calls = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic>? job;
  bool lostAck = false, missingServer = false;
  @override
  Stream<List<Map<String, dynamic>>> watch() => const Stream.empty();
  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> fields,
  ) async {
    calls.add((action, fields));
    if (missingServer) {
      throw const AiSlidesFailure('not deployed', code: 'not-found');
    }
    if (action == 'enqueue') {
      job = row(fields['requestId'] as String);
      if (lostAck) {
        throw const AiSlidesFailure('timeout', code: 'deadline-exceeded');
      }
    }
    if (action == 'asset') {
      return {
        'base64': base64Encode(templateTestPng),
        'sha256': templateTestJob('one', status: 'complete').sha256,
        'width': 1920,
        'height': 1080,
      };
    }
    if (job == null) throw const AiSlidesFailure('no job', code: 'not-found');
    return {'job': job, 'usage': usage};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final input = StudioInput(
    design: templateTestDesign,
    raw: 'Row 1,000m\nSquat 22.5kg × 12',
  );
  TemplateJobsRepositoryImpl repository(
    Source source, {
    String scope = 'dev/owner/center',
    bool Function()? current,
  }) => TemplateJobsRepositoryImpl(
    source: source,
    preferences: SharedPreferences.getInstance,
    scopeKey: scope,
    isCurrent: current ?? () => true,
  );

  test('center serializer sends canonical recipe identity and exact source, no legacy paid modes', () {
    final data = templateJobInput(
      input.copyWith(mode: StudioMode.artwork, brief: 'old'),
      'same-id',
    );
    expect(data['rawWod'], input.raw);
    expect((data['design'] as Map)['theme']['centerRecipe'], {
      'templateId': 'original',
      'revision': 2,
    });
    expect(data.containsKey('operation'), false);
    expect(data.containsKey('brief'), false);
  });
  test('lost acknowledgement persists, blocks new enqueue, restart recovers same ID without second generation', () async {
    final source = Source()..lostAck = true;
    final repo = repository(source);
    await expectLater(
      repo.enqueue(input, 'one'),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(await repo.hasUnresolved(), true);
    await expectLater(
      repo.enqueue(input, 'two'),
      throwsA(isA<AiSlidesFailure>()),
    );
    final restarted = repository(source);
    final recovered = await restarted.recover();
    expect(recovered!.jobs.single.requestId, 'one');
    expect(source.calls.where((c) => c.$1 == 'enqueue').length, 1);
    expect(await restarted.hasUnresolved(), false);
  });
  test(
    'explicit missing receipt recovery resubmits identical ID and body',
    () async {
      final source = Source()..lostAck = true;
      final repo = repository(source);
      await expectLater(
        repo.enqueue(input, 'one'),
        throwsA(isA<AiSlidesFailure>()),
      );
      source
        ..lostAck = false
        ..job = null;
      await repository(source).recover();
      final sends = source.calls.where((v) => v.$1 == 'enqueue').toList();
      expect(sends.length, 2);
      expect(sends[1].$2, sends[0].$2);
    },
  );
  test(
    'scope isolation, logout guard and missing server never invent success',
    () async {
      final source = Source()..lostAck = true;
      await expectLater(
        repository(source).enqueue(input, 'one'),
        throwsA(isA<AiSlidesFailure>()),
      );
      expect(
        await repository(source, scope: 'other/owner/center').hasUnresolved(),
        false,
      );
      await expectLater(
        repository(source, current: () => false).list(),
        throwsA(isA<AiSlidesFailure>()),
      );
      final unavailable = Source()..missingServer = true;
      final fresh = repository(unavailable, scope: 'fresh');
      await expectLater(
        fresh.enqueue(input, 'new'),
        throwsA(isA<AiSlidesFailure>()),
      );
      expect(await fresh.hasUnresolved(), false);
    },
  );
  test(
    'retry requires explicit failed retryable receipt and sends retryOf only',
    () async {
      final source = Source(), repo = repository(Source());
      expect(
        () => repo.retry(templateTestJob('one'), 'two'),
        throwsA(isA<AiSlidesFailure>()),
      );
      await repository(
        source,
      ).retry(templateTestJob('one', status: 'failed', retryable: true), 'two');
      expect(source.calls.single.$2, {'requestId': 'two', 'retryOf': 'one'});
    },
  );
  test('private PNG cache revalidates authority each time and rejects changed artifact', () async {
    final source = Source()..job = row('one', status: 'complete');
    final repo = repository(source),
        job = templateTestJob('one', status: 'complete');
    final first = await repo.asset(job);
    first[0] = 0;
    expect((await repo.asset(job))[0], 0x89);
    expect(source.calls.where((v) => v.$1 == 'asset').length, 1);
    expect(source.calls.where((v) => v.$1 == 'status').length, 2);
    source.job = row('one');
    await expectLater(repo.asset(job), throwsA(isA<AiSlidesFailure>()));
  });
  test('asset hash/dimensions and malformed job fail closed', () {
    final job = templateTestJob('one', status: 'complete');
    expect(
      () => readTemplateJobPng({
        'base64': 'AA==',
        'sha256': job.sha256,
        'width': 1920,
        'height': 1080,
      }, job),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(
      () => readTemplateJob({...row('one'), 'status': 'complete'}),
      throwsFormatException,
    );
    final parsed = readTemplateJobsReply({
      'jobs': [row('one')],
      'usage': usage,
      'nextCursor': 'one',
    });
    expect(parsed.nextCursor, 'one');
  });
}
