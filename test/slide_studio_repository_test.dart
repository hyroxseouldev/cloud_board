import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/slide_studio_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/slide_studio_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/slide_studio_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_template_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/slide_editor_repository.dart';

import 'support/ui_layout_evidence.dart';

class _NoNetwork implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Network forbidden');
}

class _Source extends SlideStudioDataSource {
  _Source() : super(_NoNetwork(), 'local-center', () => true);
  bool revoked = false;
  Object? failure;
  @override
  bool Function() get isCurrent =>
      () => !revoked;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (failure != null) throw failure!;
    return {
      'used': 2,
      'remaining': 8,
      'limit': 10,
      'allowed': true,
      'enabled': true,
      'tokenAllowance': {
        'kind': 'not-metered',
        'remaining': null,
        'limit': null,
      },
    };
  }
}

class _Legacy implements AiSlidesRepository {
  @override
  Future<AiSlidesAccess> access() async => const AiSlidesAccess(
    premium: false,
    allowed: true,
    enabled: true,
    remaining: 7,
    limit: 10,
    used: 3,
  );
  @override
  Future<AiSlidesResult> generate(String prompt) =>
      throw StateError('No automatic generation');
}

class _Library implements SlideEditorRepository {
  List<WorkoutModule> items = [WorkoutModule.empty('unrelated')];
  int writes = 0;
  bool loseResponse = true;
  @override
  Future<List<WorkoutModule>> loadTemplates(String scope) async => items;
  @override
  Future<List<WorkoutModule>> saveTemplates(
    String scope,
    List<WorkoutModule> templates, {
    List<WorkoutModule>? previous,
  }) async {
    writes++;
    items = templates;
    if (loseResponse) throw Exception('response lost after commit');
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected library operation');
}

void main() {
  SlideStudioRepositoryImpl create(_Source source, _Library library) =>
      SlideStudioRepositoryImpl(
        source: source,
        ownerId: 'local-owner',
        center: CenterSlideTemplateActions(
          repository: null,
          scope: null,
          isCurrent: () => true,
        ),
        raster: null,
        library: library,
        legacy: _Legacy(),
      );

  test('optional token contract preserves old request counts, and malformed values never become zero', () {
    final old = readStudioUsage({
      'used': 3,
      'remaining': 7,
      'limit': 10,
      'allowed': true,
      'enabled': true,
    });
    expect(old.remaining, 7);
    expect(old.tokenContractAvailable, false);
    expect(old.lastInputTokens, isNull);
    expect(old.unlimited, false);
    final unlimited = readStudioUsage({
      'used': 4,
      'remaining': null,
      'limit': null,
      'unlimited': true,
      'allowed': true,
      'enabled': true,
    });
    expect(unlimited.unlimited, true);
    expect(
      () => readStudioUsage({'remaining': 10, 'limit': 10}),
      throwsA(isA<AiSlidesFailure>()),
    );
    final unknown = readStudioUsage({
      'used': 2,
      'remaining': 8,
      'limit': 10,
      'lastOperationTokens': {'input': -1, 'output': 5},
    });
    expect(unknown.lastInputTokens, isNull);
  });
  test('not deployed optional API falls back to old counts without claiming token support', () async {
    final source = _Source()
      ..failure = const AiSlidesFailure('not deployed', code: 'not-found');
    final repository = create(source, _Library());
    final usage = await repository.usage();
    expect(usage.remaining, 7);
    expect(usage.tokenContractAvailable, false);
    source.failure = const AiSlidesFailure('offline', code: 'unavailable');
    await expectLater(repository.usage(), throwsA(isA<AiSlidesFailure>()));
  });
  test('lost library acknowledgment retries same result ID without overwrite, duplicate or deleting unrelated slides', () async {
    final source = _Source(), library = _Library();
    final repository = create(source, library);
    final module = WorkoutModule.empty('studio-stable-result')
        .copyWith(text: 'Run 800m', name: '오늘 수업');
    await expectLater(repository.save(module), throwsException);
    final acknowledged = await repository.save(module);
    expect(acknowledged, module);
    expect(library.writes, 1);
    expect(library.items.map((item) => item.id), [
      'unrelated',
      'studio-stable-result',
    ]);
    source.revoked = true;
    await expectLater(repository.save(module), throwsA(isA<AiSlidesFailure>()));
    expect(library.writes, 1);
  });
  testWidgets(
    'real template preview validation is encode-free and final preparation reuses exact PNG',
    (tester) async {
      await loadLayoutFonts(tester);
      final source = _Source(), repository = create(_Source(), _Library());
      final input = StudioInput(
        design: aiSlideDesignCatalog.first,
        raw: 'Run 800m\nSquat 12',
      );
      final draft = studioDraft(input),
          result = StudioResult(
            id: 'studio-png',
            input: input,
            draft: studioDraft(input),
          );
      await repository.validate(draft);
      await tester.runAsync(() async {
        final first = await repository.prepare(result),
            second = await repository.prepare(result);
        expect(identical(first, second), true);
        expect(first.imageSource, startsWith('data:image/png;base64,'));
        expect(first.text, input.raw);
      });
      source.revoked = true;
      await expectLater(
        create(source, _Library()).prepare(result),
        throwsA(isA<AiSlidesFailure>()),
      );
    },
  );
}
